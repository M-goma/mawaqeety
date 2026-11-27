using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using Mawaqeety.App.Localization;
using Mawaqeety.App.Services;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.ViewModels;

/// <summary>A combo-box option whose label follows the UI language.</summary>
public sealed partial class Option<T>(T value, Func<string> label) : ObservableObject
{
    public T Value { get; } = value;
    public string Label => label();
    public void Refresh() => OnPropertyChanged(nameof(Label));
    public override string ToString() => Label;
}

public sealed partial class PrayerAlertViewModel : ObservableObject
{
    private readonly SettingsStore _store;
    public Prayer Prayer { get; }
    public IReadOnlyList<Option<AlertMode>> Modes { get; }

    public PrayerAlertViewModel(Prayer prayer, SettingsStore store, IReadOnlyList<Option<AlertMode>> modes)
    {
        Prayer = prayer;
        _store = store;
        Modes = modes;
    }

    private PrayerAlertSettings A => _store.Current.AlertFor(Prayer);

    public string Name => Loc.I.Prayer(Prayer);

    public bool Enabled
    {
        get => A.Enabled;
        set { _store.Update(_ => A.Enabled = value); OnPropertyChanged(); }
    }

    public AlertMode Mode
    {
        get => A.Mode;
        set { _store.Update(_ => A.Mode = value); OnPropertyChanged(); }
    }

    public int Adjustment
    {
        get => A.AdjustmentMinutes;
        set { _store.Update(_ => A.AdjustmentMinutes = Math.Clamp(value, -60, 60), affectsTimes: true); OnPropertyChanged(); }
    }

    public string SoundName
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(A.SoundPath)) return Path.GetFileName(A.SoundPath);
            var sound = Core.Audio.AlertSoundResolver.Resolve(Prayer, AlertKind.AtTime, _store.Current);
            return sound.Adhan is { } v ? string.Format(Loc.T("SoundAdhan"), v.DisplayName(Loc.I.IsArabic)) : Loc.T("DefaultSound");
        }
    }

    [RelayCommand]
    private void Browse()
    {
        var dlg = new OpenFileDialog { Filter = $"{Loc.T("SoundFiles")} (*.mp3;*.wav;*.wma;*.m4a)|*.mp3;*.wav;*.wma;*.m4a" };
        if (dlg.ShowDialog() != true) return;
        _store.Update(_ => A.SoundPath = dlg.FileName);
        OnPropertyChanged(nameof(SoundName));
    }

    [RelayCommand]
    private void ResetSound()
    {
        _store.Update(_ => A.SoundPath = null);
        OnPropertyChanged(nameof(SoundName));
    }

    [RelayCommand]
    private async Task Test()
    {
        var app = App.Instance;
        if (app.Sound.IsPlaying) { app.Sound.Stop(); return; }
        var sound = Core.Audio.AlertSoundResolver.Resolve(Prayer, AlertKind.AtTime, _store.Current);
        if (sound.Adhan is { } v) await app.Adhan.EnsureAsync(v);
        app.Sound.Play(app.Adhan.PathToPlay(sound), _store.Current.Volume);
    }

    [RelayCommand]
    private void AdjustUp() => Adjustment++;

    [RelayCommand]
    private void AdjustDown() => Adjustment--;

    public void RefreshLanguage()
    {
        OnPropertyChanged(nameof(Name));
        OnPropertyChanged(nameof(SoundName));
    }
}

public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsStore _store = App.Instance.Settings;
    private CancellationTokenSource? _searchCts;
    private AppSettings S => _store.Current;

    public IReadOnlyList<Option<MethodId>> Methods { get; }
    public IReadOnlyList<Option<AsrMadhab>> Madhabs { get; }
    public IReadOnlyList<Option<HighLatitudeRule>> HighLatRules { get; }
    public IReadOnlyList<Option<AlertMode>> Modes { get; }
    public IReadOnlyList<Option<AlertMode>> PreModes { get; }
    public IReadOnlyList<Option<AppTheme>> Themes { get; }
    public IReadOnlyList<Option<AppLanguage>> Languages { get; }
    public IReadOnlyList<Option<TimeSource>> Sources { get; }
    public IReadOnlyList<Option<int>> PreAlertChoices { get; }
    public IReadOnlyList<Option<string>> TimeZones { get; }
    public IReadOnlyList<Option<string>> AdhanVoices { get; }
    public IReadOnlyList<Option<string>> FajrAdhanVoices { get; }
    public ObservableCollection<PrayerAlertViewModel> PrayerAlerts { get; }
    public ObservableCollection<GeoLocation> SearchResults { get; } = [];

    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private string _searchStatus = "";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _syncStatus = "";
    [ObservableProperty] private string _manualLat = "";
    [ObservableProperty] private string _manualLng = "";
    [ObservableProperty] private string _savedHint = "";

    public SettingsViewModel()
    {
        var l = Loc.I;
        Methods = CalculationMethod.All.Select(m => new Option<MethodId>(m.Id, () => Loc.I.IsArabic ? m.NameAr : m.NameEn)).ToList();
        Madhabs = [new(AsrMadhab.Shafii, () => Loc.T("Shafii")), new(AsrMadhab.Hanafi, () => Loc.T("Hanafi"))];
        HighLatRules = Enum.GetValues<HighLatitudeRule>().Select(r => new Option<HighLatitudeRule>(r, () => Loc.T("HL_" + r))).ToList();
        Modes = Enum.GetValues<AlertMode>().Select(m => new Option<AlertMode>(m, () => Loc.T("Mode_" + m))).ToList();
        PreModes = Modes;
        Themes = Enum.GetValues<AppTheme>().Select(t => new Option<AppTheme>(t, () => Loc.T("Theme_" + t))).ToList();
        Languages = [new(AppLanguage.Arabic, () => "العربية"), new(AppLanguage.English, () => "English")];
        Sources = Enum.GetValues<TimeSource>().Select(t => new Option<TimeSource>(t, () => Loc.T("Src_" + t))).ToList();
        PreAlertChoices = new[] { 5, 10, 15, 20, 30, 45, 60 }
            .Select(m => new Option<int>(m, () => $"{m} {Loc.T("Minutes")}")).Append(new Option<int>(-1, () => Loc.T("Custom"))).ToList();
        TimeZones = TimeZoneInfo.GetSystemTimeZones().Select(z => new Option<string>(z.Id, () => z.DisplayName)).ToList();
        AdhanVoices = Core.Audio.AdhanCatalog.Regular.Select(v => new Option<string>(v.Id, () => v.DisplayName(Loc.I.IsArabic))).ToList();
        FajrAdhanVoices = Core.Audio.AdhanCatalog.ForFajr.Select(v => new Option<string>(v.Id, () => v.DisplayName(Loc.I.IsArabic))).ToList();
        App.Instance.Adhan.Downloaded += _ => App.Instance.Dispatcher.BeginInvoke(RefreshAdhanStatus);
        App.Instance.Sound.PlayingChanged += _ => App.Instance.Dispatcher.BeginInvoke(() => OnPropertyChanged(nameof(PreviewLabel)));
        PrayerAlerts = new(PrayerExtensions.All.Select(p => new PrayerAlertViewModel(p, _store, Modes)));
        ManualLat = S.Location.Latitude.ToString("0.####", CultureInfo.InvariantCulture);
        ManualLng = S.Location.Longitude.ToString("0.####", CultureInfo.InvariantCulture);

        l.LanguageChanged += (_, _) =>
        {
            foreach (var o in Methods) o.Refresh();
            foreach (var o in Madhabs) o.Refresh();
            foreach (var o in HighLatRules) o.Refresh();
            foreach (var o in Modes) o.Refresh();
            foreach (var o in Themes) o.Refresh();
            foreach (var o in Sources) o.Refresh();
            foreach (var o in PreAlertChoices) o.Refresh();
            foreach (var o in AdhanVoices) o.Refresh();
            foreach (var o in FajrAdhanVoices) o.Refresh();
            RefreshAdhanStatus();
            foreach (var p in PrayerAlerts) p.RefreshLanguage();
            OnPropertyChanged(nameof(LocationName));
        };
        _store.Changed += _ => App.Instance.Dispatcher.BeginInvoke(() => SavedHint = Loc.T("Saved"));
        RefreshAdhanStatus();
    }

    // ---------------- location ----------------
    public string LocationName => S.Location.DisplayName(Loc.I.IsArabic);
    public string LocationDetails => string.Create(CultureInfo.InvariantCulture,
        $"{S.Location.Latitude:0.####}°, {S.Location.Longitude:0.####}°  •  {S.Location.TimeZoneId}");

    partial void OnSearchTextChanged(string value)
    {
        SearchResults.Clear();
        foreach (var c in App.Instance.LocationSearch.SearchOffline(value)) SearchResults.Add(c);
        SearchStatus = value.Trim().Length >= 2 && SearchResults.Count == 0 ? Loc.T("NoResults") : "";
    }

    [RelayCommand]
    private async Task SearchOnline()
    {
        if (string.IsNullOrWhiteSpace(SearchText)) return;
        _searchCts?.Cancel();
        _searchCts = new CancellationTokenSource();
        SearchStatus = Loc.T("Searching");
        IsBusy = true;
        try
        {
            var results = await App.Instance.LocationSearch.SearchOnlineAsync(SearchText, _searchCts.Token);
            SearchResults.Clear();
            foreach (var r in results) SearchResults.Add(r);
            SearchStatus = results.Count == 0 ? Loc.T("NoResults") : "";
        }
        catch (OperationCanceledException) { }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SelectLocation(GeoLocation? loc)
    {
        if (loc is null) return;
        IsBusy = true;
        try
        {
            var complete = await App.Instance.LocationSearch.CompleteAsync(loc, CancellationToken.None);
            ApplyLocation(complete);
            SearchText = "";
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DetectLocation()
    {
        IsBusy = true;
        SearchStatus = Loc.T("Detecting");
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            var loc = await App.Instance.Location.DetectAsync(cts.Token);
            if (loc is null) { SearchStatus = Loc.T("DetectFailed"); return; }
            ApplyLocation(loc);
            SearchStatus = "";
        }
        catch (Exception ex)
        {
            App.Instance.Log.Warn("Detect location failed", ex);
            SearchStatus = Loc.T("DetectFailed");
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task ApplyManualCoordinates()
    {
        if (!double.TryParse(ManualLat, NumberStyles.Float, CultureInfo.InvariantCulture, out var lat) || lat is < -90 or > 90 ||
            !double.TryParse(ManualLng, NumberStyles.Float, CultureInfo.InvariantCulture, out var lng) || lng is < -180 or > 180)
        {
            SearchStatus = Loc.T("Error");
            return;
        }
        IsBusy = true;
        try { ApplyLocation(await App.Instance.LocationSearch.FromCoordinatesAsync(lat, lng, CancellationToken.None)); }
        finally { IsBusy = false; }
    }

    private void ApplyLocation(GeoLocation loc)
    {
        var countryChanged = !string.Equals(loc.CountryCode, S.Location.CountryCode, StringComparison.OrdinalIgnoreCase);
        _store.Update(s =>
        {
            s.Location = loc;
            s.AutoTimeZone = true;
            if (countryChanged && !string.IsNullOrEmpty(loc.CountryCode))
            {
                // Sensible defaults for the new country; the user can still override them.
                s.Method = CalculationMethod.DefaultForCountry(loc.CountryCode);
                s.Madhab = CalculationMethod.DefaultMadhabForCountry(loc.CountryCode);
            }
        }, affectsTimes: true);
        App.Instance.Db.TouchRecentLocation(loc, DateTimeOffset.UtcNow);
        ManualLat = loc.Latitude.ToString("0.####", CultureInfo.InvariantCulture);
        ManualLng = loc.Longitude.ToString("0.####", CultureInfo.InvariantCulture);
        SearchResults.Clear();
        OnPropertyChanged(string.Empty); // refresh every bound property
        _ = SyncIfOnlineAsync();
    }

    // ---------------- time zone ----------------
    public bool AutoTimeZone
    {
        get => S.AutoTimeZone;
        set { _store.Update(s => s.AutoTimeZone = value, true); OnPropertyChanged(); }
    }

    public string TimeZoneId
    {
        get => S.Location.TimeZoneId;
        set
        {
            if (string.IsNullOrEmpty(value)) return;
            _store.Update(s => s.Location = s.Location with { TimeZoneId = value }, true);
            OnPropertyChanged();
            OnPropertyChanged(nameof(LocationDetails));
        }
    }

    public int ManualOffset
    {
        get => S.ManualUtcOffsetMinutes;
        set { _store.Update(s => s.ManualUtcOffsetMinutes = Math.Clamp(value, -720, 840), true); OnPropertyChanged(); }
    }

    public bool ManualDst
    {
        get => S.ManualDstEnabled;
        set { _store.Update(s => s.ManualDstEnabled = value, true); OnPropertyChanged(); }
    }

    // ---------------- calculation ----------------
    public MethodId Method
    {
        get => S.Method;
        set { _store.Update(s => s.Method = value, true); OnPropertyChanged(); OnPropertyChanged(nameof(IsCustomMethod)); _ = SyncIfOnlineAsync(); }
    }

    public bool IsCustomMethod => S.Method == MethodId.Custom;

    public double CustomFajr
    {
        get => S.CustomFajrAngle;
        set { _store.Update(s => s.CustomFajrAngle = Math.Clamp(value, 5, 25), true); OnPropertyChanged(); }
    }

    public double CustomIsha
    {
        get => S.CustomIshaAngle;
        set { _store.Update(s => s.CustomIshaAngle = Math.Clamp(value, 5, 25), true); OnPropertyChanged(); }
    }

    public AsrMadhab Madhab
    {
        get => S.Madhab;
        set { _store.Update(s => s.Madhab = value, true); OnPropertyChanged(); _ = SyncIfOnlineAsync(); }
    }

    public HighLatitudeRule HighLat
    {
        get => S.HighLatitudeRule;
        set { _store.Update(s => s.HighLatitudeRule = value, true); OnPropertyChanged(); }
    }

    public TimeSource Source
    {
        get => S.Source;
        set { _store.Update(s => s.Source = value, true); OnPropertyChanged(); OnPropertyChanged(nameof(IsOnline)); _ = SyncIfOnlineAsync(); }
    }

    public bool IsOnline => S.Source == TimeSource.OnlineWithLocalFallback;

    public int HijriAdjustment
    {
        get => S.HijriAdjustmentDays;
        set { _store.Update(s => s.HijriAdjustmentDays = Math.Clamp(value, -3, 3)); OnPropertyChanged(); }
    }

    [RelayCommand] private void HijriUp() => HijriAdjustment++;
    [RelayCommand] private void HijriDown() => HijriAdjustment--;

    [RelayCommand]
    private async Task SyncNow()
    {
        IsBusy = true;
        try
        {
            var ok = await App.Instance.Times.SyncAsync(S, DateOnly.FromDateTime(DateTime.Today), CancellationToken.None);
            SyncStatus = Loc.T(ok ? "SyncOk" : "SyncFailed");
            if (ok) _store.Update(_ => { }, true);
        }
        finally { IsBusy = false; }
    }

    private async Task SyncIfOnlineAsync()
    {
        if (!IsOnline) return;
        await SyncNow();
    }

    // ---------------- adhan ----------------
    [ObservableProperty] private string _adhanStatus = "";
    [ObservableProperty] private string _fajrAdhanStatus = "";

    public bool AdhanEnabled
    {
        get => S.AdhanEnabled;
        set
        {
            _store.Update(s => s.AdhanEnabled = value);
            OnPropertyChanged();
            RefreshAdhanStatus();
            foreach (var p in PrayerAlerts) p.RefreshLanguage();
            if (value) _ = DownloadSelectedAsync();
        }
    }

    public string AdhanId
    {
        get => S.AdhanId;
        set
        {
            if (string.IsNullOrEmpty(value) || value == S.AdhanId) return;
            _store.Update(s => s.AdhanId = value);
            OnPropertyChanged();
            _ = DownloadSelectedAsync();
        }
    }

    public string FajrAdhanId
    {
        get => S.FajrAdhanId;
        set
        {
            if (string.IsNullOrEmpty(value) || value == S.FajrAdhanId) return;
            _store.Update(s => s.FajrAdhanId = value);
            OnPropertyChanged();
            _ = DownloadSelectedAsync();
        }
    }

    public string PreviewLabel => App.Instance.Sound.IsPlaying ? Loc.T("StopPreview") : Loc.T("Preview");

    [RelayCommand] private Task PreviewAdhan() => PreviewAsync(S.AdhanId);
    [RelayCommand] private Task PreviewFajrAdhan() => PreviewAsync(S.FajrAdhanId);

    private async Task PreviewAsync(string id)
    {
        var app = App.Instance;
        if (app.Sound.IsPlaying) { app.Sound.Stop(); return; }
        if (Core.Audio.AdhanCatalog.Find(id) is not { } v) return;
        if (!app.Adhan.IsAvailable(v))
        {
            SetStatus(v, Loc.T("AdhanDownloading"));
            if (!await app.Adhan.EnsureAsync(v)) { SetStatus(v, Loc.T("AdhanFailed")); return; }
            RefreshAdhanStatus();
        }
        app.Sound.Play(app.Adhan.LocalPath(v), S.Volume);
    }

    private async Task DownloadSelectedAsync()
    {
        RefreshAdhanStatus();
        foreach (var id in new[] { S.AdhanId, S.FajrAdhanId }.Distinct())
        {
            if (Core.Audio.AdhanCatalog.Find(id) is not { } v || App.Instance.Adhan.IsAvailable(v)) continue;
            SetStatus(v, Loc.T("AdhanDownloading"));
            if (!await App.Instance.Adhan.EnsureAsync(v)) SetStatus(v, Loc.T("AdhanPending"));
        }
        RefreshAdhanStatus();
        foreach (var p in PrayerAlerts) p.RefreshLanguage();
    }

    private void SetStatus(Core.Audio.AdhanVoice v, string text)
    {
        if (v.Id == S.AdhanId) AdhanStatus = text;
        if (v.Id == S.FajrAdhanId) FajrAdhanStatus = text;
    }

    private void RefreshAdhanStatus()
    {
        string Status(string id) => Core.Audio.AdhanCatalog.Find(id) is { } v && App.Instance.Adhan.IsAvailable(v)
            ? Loc.T("AdhanReady") : Loc.T("AdhanPending");
        AdhanStatus = Status(S.AdhanId);
        FajrAdhanStatus = Status(S.FajrAdhanId);
        OnPropertyChanged(nameof(PreviewLabel));
    }

    // ---------------- alerts ----------------
    public bool PreAlertEnabled
    {
        get => S.PreAlertEnabled;
        set { _store.Update(s => s.PreAlertEnabled = value); OnPropertyChanged(); }
    }

    private bool _customPreAlertSelected;

    /// <summary>Selected preset, or -1 for a custom value.</summary>
    public int PreAlertChoice
    {
        get => _customPreAlertSelected || PreAlertChoices.All(c => c.Value != S.PreAlertMinutes) ? -1 : S.PreAlertMinutes;
        set
        {
            _customPreAlertSelected = value == -1;
            if (value > 0) _store.Update(s => s.PreAlertMinutes = value);
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsCustomPreAlert));
            OnPropertyChanged(nameof(PreAlertMinutes));
        }
    }

    public bool IsCustomPreAlert => PreAlertChoice == -1;

    public int PreAlertMinutes
    {
        get => S.PreAlertMinutes;
        set { _store.Update(s => s.PreAlertMinutes = Math.Clamp(value, 1, 180)); OnPropertyChanged(); }
    }

    public AlertMode PreAlertMode
    {
        get => S.PreAlertMode;
        set { _store.Update(s => s.PreAlertMode = value); OnPropertyChanged(); }
    }

    public bool MuteAll
    {
        get => S.MuteAllSounds;
        set { _store.Update(s => s.MuteAllSounds = value); OnPropertyChanged(); if (value) App.Instance.Sound.Stop(); }
    }

    public double Volume
    {
        get => S.Volume * 100;
        set { _store.Update(s => s.Volume = Math.Clamp(value / 100, 0, 1)); OnPropertyChanged(); }
    }

    [RelayCommand]
    private void TestNotification()
    {
        var app = App.Instance;
        var st = app.ComputeStatus(DateTimeOffset.Now);
        app.Toast.ShowAlert(new Core.Scheduling.PlannedAlert(DateOnly.FromDateTime(DateTime.Today), st.Next, AlertKind.AtTime,
            DateTimeOffset.Now, st.NextTime, AlertMode.NotificationWithSound, S.AlertFor(st.Next).SoundPath, 0), withStopButton: !S.MuteAllSounds, S.Use24HourClock);
        if (!S.MuteAllSounds) app.Sound.Play(app.Adhan.PathToPlay(Core.Audio.AlertSoundResolver.Resolve(st.Next, AlertKind.AtTime, S)), S.Volume);
    }

    // ---------------- appearance / system ----------------
    public AppTheme Theme
    {
        get => S.Theme;
        set { _store.Update(s => s.Theme = value); ThemeService.Apply(value); OnPropertyChanged(); }
    }

    public IReadOnlyList<Core.Content.Palette> Palettes => Core.Content.Palette.All;

    public string PaletteId
    {
        get => Core.Content.Palette.Find(S.Palette).Id;
        set
        {
            if (value == PaletteId) return;
            _store.Update(s => s.Palette = value);
            ThemeService.Apply(S.Theme, value);
            OnPropertyChanged();
        }
    }

    [RelayCommand]
    private void SelectPalette(string? id) { if (id is not null) PaletteId = id; }

    public bool WidgetEnabled
    {
        get => S.WidgetEnabled;
        set { _store.Update(s => s.WidgetEnabled = value); App.Instance.UpdateWidget(); OnPropertyChanged(); }
    }

    public bool PrayerCheck
    {
        get => S.PrayerCheck;
        set { _store.Update(s => s.PrayerCheck = value); OnPropertyChanged(); }
    }

    public bool FridayKahf
    {
        get => S.FridayKahf;
        set { _store.Update(s => s.FridayKahf = value); OnPropertyChanged(); }
    }

    public bool FridayHour
    {
        get => S.FridayHour;
        set { _store.Update(s => s.FridayHour = value); OnPropertyChanged(); }
    }

    public bool WidgetTopmost
    {
        get => S.WidgetTopmost;
        set { _store.Update(s => s.WidgetTopmost = value); App.Instance.UpdateWidget(); OnPropertyChanged(); }
    }

    public AppLanguage Language
    {
        get => S.Language;
        set { _store.Update(s => s.Language = value); Loc.I.SetLanguage(value); OnPropertyChanged(); }
    }

    public bool Use24h
    {
        get => S.Use24HourClock;
        set { _store.Update(s => s.Use24HourClock = value); OnPropertyChanged(); }
    }

    public bool StartWithWindows
    {
        get => S.StartWithWindows;
        set
        {
            _store.Update(s => s.StartWithWindows = value);
            try { AutoStartService.Apply(value); }
            catch (Exception ex) { App.Instance.Log.Warn("Auto-start change failed", ex); }
            OnPropertyChanged();
        }
    }

    public bool StartMinimized
    {
        get => S.StartMinimized;
        set { _store.Update(s => s.StartMinimized = value); OnPropertyChanged(); }
    }

    public bool CloseToTray
    {
        get => S.MinimizeToTrayOnClose;
        set { _store.Update(s => s.MinimizeToTrayOnClose = value); OnPropertyChanged(); }
    }

    [RelayCommand]
    private void OpenLogs() => Process.Start(new ProcessStartInfo(AppPaths.LogDir) { UseShellExecute = true });
}
