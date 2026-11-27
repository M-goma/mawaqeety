using System.Collections.ObjectModel;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.App.Localization;
using Mawaqeety.Core;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.App.ViewModels;

public sealed partial class PrayerRowViewModel : ObservableObject
{
    public Prayer Prayer { get; init; }
    public string Icon { get; init; } = "";
    [ObservableProperty] private string _name = "";
    [ObservableProperty] private string _time = "";
    [ObservableProperty] private bool _isNext;
    [ObservableProperty] private bool _isCurrent;
    [ObservableProperty] private bool _isPassed;
    [ObservableProperty] private string _badge = "";
    /// <summary>The prayer time has come, so it can be logged (not for sunrise).</summary>
    [ObservableProperty] private bool _canLog;
    [ObservableProperty] private PrayerLog _log;
    [ObservableProperty] private string _logText = "";
}

public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly DispatcherTimer _timer;
    private DateOnly _loadedDate;
    private DailyPrayerTimes? _today;
    private DateOnly _harvestDate;
    private int _harvestTick;

    public ObservableCollection<PrayerRowViewModel> Rows { get; } = new(PrayerExtensions.All.Select(p => new PrayerRowViewModel
    {
        Prayer = p,
        // Segoe Fluent Icons glyphs
        Icon = p switch
        {
            Prayer.Fajr => "",      // quiet hours / moon
            Prayer.Sunrise => "",   // brightness
            Prayer.Dhuhr => "",     // sunny-ish
            Prayer.Asr => "",       // partly sunny
            Prayer.Maghrib => "",   // power/sunset-ish
            _ => "",                // night
        },
    }));

    [ObservableProperty] private string _cityName = "";
    [ObservableProperty] private string _gregorianDate = "";
    [ObservableProperty] private string _hijriDate = "";
    [ObservableProperty] private string _clock = "";
    [ObservableProperty] private string _nextPrayerName = "";
    [ObservableProperty] private string _nextPrayerTime = "";
    [ObservableProperty] private string _countdown = "";
    [ObservableProperty] private double _progress;
    [ObservableProperty] private string _currentStatus = "";
    [ObservableProperty] private string _methodText = "";
    [ObservableProperty] private string _sourceText = "";
    [ObservableProperty] private string _pausedText = "";
    [ObservableProperty] private bool _isPaused;

    // ---------------- today's harvest ----------------
    [ObservableProperty] private double _harvest;
    [ObservableProperty] private string _harvestPercent = "";
    [ObservableProperty] private string _harvestLeft = "";
    [ObservableProperty] private string _prayersChip = "";
    [ObservableProperty] private bool _morningDone;
    [ObservableProperty] private bool _eveningDone;
    [ObservableProperty] private string _wirdChip = "";
    [ObservableProperty] private bool _hasWird;

    private void UpdateHarvest(DateOnly date)
    {
        var t = App.Instance.Tracker;
        var d = t.Day(date);
        var goal = App.Instance.Settings.Current.WirdGoal;
        Harvest = t.Completion(date);
        HarvestPercent = Core.Content.QuranRepository.ArabicDigits((int)Math.Round(Harvest * 100)) + "٪";
        var left = new List<string>();
        if (d.PrayersDone < 5) left.Add($"{Core.Content.QuranRepository.ArabicDigits(5 - d.PrayersDone)} صلوات");
        if (!d.Morning) left.Add("أذكار الصباح");
        if (!d.Evening) left.Add("أذكار المساء");
        if (goal > 0 && d.Tasbeeh < goal) left.Add("الورد");
        HarvestLeft = left.Count == 0 ? "أتممت يومك، تقبّل الله منك 🤍" : "باقي: " + string.Join("، ", left);
        PrayersChip = $"🕌 {Core.Content.QuranRepository.ArabicDigits(d.PrayersDone)}/٥";
        MorningDone = d.Morning;
        EveningDone = d.Evening;
        HasWird = goal > 0;
        WirdChip = $"📿 {Core.Content.QuranRepository.ArabicDigits(d.Tasbeeh)}/{Core.Content.QuranRepository.ArabicDigits(goal)}";
        foreach (var r in Rows)
        {
            r.Log = d.Of(r.Prayer);
            r.LogText = r.Log == PrayerLog.None ? "＋ سجّل صلاتك" : $"{r.Log.Emoji()} {r.Log.Label()}";
        }
    }

    /// <summary>Logs how a prayer was prayed today (None removes it).</summary>
    public void LogPrayer(PrayerRowViewModel row, PrayerLog log)
    {
        var app = App.Instance;
        var today = app.Today;
        app.Tracker.SetPrayer(today, row.Prayer, log);
        var d = app.Tracker.Day(today);
        var streak = app.Tracker.PrayersStreak(today);
        if (d.AllFiveOnTime && new[] { 3, 7, 14, 21, 30, 40, 60, 100, 200, 365 }.Contains(streak))
            app.Toast.Show($"🔥 أحسنت! {Core.Content.QuranRepository.ArabicDigits(streak)} أيام متتالية للصلوات الخمس", "استمر، أحب الأعمال إلى الله أدومها وإن قلّ.", tag: "streak");
    }

    [RelayCommand] private void ToggleMorning() => App.Instance.Tracker.SetAdhkar(App.Instance.Today, morning: true, done: !MorningDone);
    [RelayCommand] private void ToggleEvening() => App.Instance.Tracker.SetAdhkar(App.Instance.Today, morning: false, done: !EveningDone);
    [RelayCommand] private void OpenStats() { if (App.Instance.MainVm is { } m) m.Page = Page.Stats; }

    public DashboardViewModel()
    {
        _timer = new DispatcherTimer(DispatcherPriority.Render) { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += (_, _) => Tick();
        Loc.I.LanguageChanged += (_, _) => Reload();
        App.Instance.Settings.Changed += _ => App.Instance.Dispatcher.BeginInvoke(Reload);
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(() => UpdateHarvest(App.Instance.Today));
        App.Instance.Radio.Changed += UpdateRadio;
        UpdateRadio();
        Reload();
    }

    // ---------------- Quran radio ----------------
    [ObservableProperty] private bool _radioOn;
    [ObservableProperty] private string _radioStatus = "";
    [ObservableProperty] private int _radioSleep;

    private void UpdateRadio()
    {
        var r = App.Instance.Radio;
        RadioOn = r.IsOn;
        RadioSleep = r.SleepMinutes;
        RadioStatus = r.Error ?? (r.IsOn
            ? (r.SleepAt is { } t ? $"بث مباشر • يتوقف {t:h:mm}" : "بث مباشر")
            : "اضغط للاستماع");
    }

    [RelayCommand] private void ToggleRadio() => App.Instance.Radio.Toggle();
    [RelayCommand] private void RadioSleepFor(string minutes) => App.Instance.Radio.SetSleep(int.Parse(minutes));

    public void Start()
    {
        Reload();
        _timer.Start();
    }

    public void Stop() => _timer.Stop();

    public void Reload()
    {
        _loadedDate = default;
        Tick();
    }

    private void Tick()
    {
        var app = App.Instance;
        var s = app.Settings.Current;
        var zone = s.ResolveZone();
        var now = DateTimeOffset.Now;
        var local = TimeZoneInfo.ConvertTime(now, zone);
        var date = DateOnly.FromDateTime(local.DateTime);
        var loc = Loc.I;

        if (date != _loadedDate) // first run or midnight passed: refresh daily data
        {
            _loadedDate = date;
            _today = app.Times.GetDay(date, s);
            CityName = s.Location.DisplayName(loc.IsArabic);
            GregorianDate = local.ToString(loc.IsArabic ? "dddd، d MMMM yyyy" : "dddd, d MMMM yyyy", loc.Culture);
            HijriDate = Core.HijriDate.From(date, s.HijriAdjustmentDays).ToDisplay(loc.IsArabic);
            var method = s.Method == MethodId.Custom ? null : CalculationMethod.Get(s.Method);
            MethodText = method is null
                ? $"{loc["Custom"]} ({s.CustomFajrAngle}° / {s.CustomIshaAngle}°)"
                : (loc.IsArabic ? method.NameAr : method.NameEn);
            SourceText = _today.Source == "aladhan" ? loc["SourceOnline"] : loc["SourceLocal"];
            foreach (var r in Rows)
            {
                r.Name = r.Prayer == Prayer.Dhuhr && local.DayOfWeek == DayOfWeek.Friday ? loc["Friday"] : loc.Prayer(r.Prayer);
                r.Time = loc.FormatTime(_today[r.Prayer], s.Use24HourClock);
            }
        }

        Clock = local.ToString(s.Use24HourClock ? "HH:mm:ss" : "hh:mm:ss tt", loc.Culture);
        var st = app.ComputeStatus(now);
        NextPrayerName = loc.Prayer(st.Next);
        NextPrayerTime = loc.FormatTime(st.NextTime, s.Use24HourClock);
        Countdown = loc.FormatCountdown(st.Remaining);
        Progress = st.Progress;
        CurrentStatus = st.Current is { } c ? string.Format(loc["CurrentPrayerTime"], loc.Prayer(c)) : loc["NoCurrentPrayer"];

        foreach (var r in Rows)
        {
            var t = _today![r.Prayer];
            r.IsNext = r.Prayer == st.Next && st.NextTime == t;
            r.IsCurrent = st.Current == r.Prayer && st.CurrentStart == t;
            r.IsPassed = t <= now && !r.IsCurrent;
            r.Badge = r.IsNext ? loc["Next"] : r.IsCurrent ? loc["Now"] : "";
            r.CanLog = r.Prayer != Prayer.Sunrise && t <= now;
        }
        if (_harvestDate != date || _harvestTick++ % 30 == 0) { _harvestDate = date; UpdateHarvest(date); }

        IsPaused = s.PausedUntil is { } p && p > now;
        PausedText = IsPaused ? string.Format(loc["AlertsPaused"], loc.FormatTime(TimeZoneInfo.ConvertTime(s.PausedUntil!.Value, zone), s.Use24HourClock)) : "";
    }

    [RelayCommand]
    private void Resume() => App.Instance.Settings.Update(s => s.PausedUntil = null);

    [RelayCommand]
    private void ChangeLocation()
    {
        if (App.Instance.MainVm is { } m) m.Page = Page.Settings;
    }
}
