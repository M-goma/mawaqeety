using System.Collections.ObjectModel;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.App.Localization;
using Mawaqeety.Core;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;

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
}

public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly DispatcherTimer _timer;
    private DateOnly _loadedDate;
    private DailyPrayerTimes? _today;

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

    public DashboardViewModel()
    {
        _timer = new DispatcherTimer(DispatcherPriority.Render) { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += (_, _) => Tick();
        Loc.I.LanguageChanged += (_, _) => Reload();
        App.Instance.Settings.Changed += _ => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

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
        }

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
