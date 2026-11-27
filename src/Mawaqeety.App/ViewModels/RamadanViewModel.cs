using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record RakahOption(int Rakahs, string Label, bool Selected);

/// <summary>One day of Ramadan in the statistics grid. Level: how many of fast / taraweeh / tahajjud were done (0..3).</summary>
public sealed record RamadanDay(string Number, string Icons, int Level, bool LastTen, bool IsToday)
{
    public double Fill => Level == 0 ? 0 : 0.25 + 0.25 * Level;
}

/// <summary>رمضان: the fast, taraweeh and tahajjud of each day, with Ramadan's own statistics (like the mobile app).</summary>
public sealed partial class RamadanViewModel : ObservableObject
{
    private static readonly int[] RakahChoices = [0, 8, 11, 20, 23];

    [ObservableProperty] private bool _inRamadan;
    [ObservableProperty] private string _heroTop = "";
    [ObservableProperty] private string _heroMain = "";
    [ObservableProperty] private string _heroSub = "";
    [ObservableProperty] private double _progress;
    [ObservableProperty] private string _todayTitle = "";
    [ObservableProperty] private string _qiyamText = "";
    [ObservableProperty] private string _statsTitle = "";
    [ObservableProperty] private string _fastedText = "";
    [ObservableProperty] private string _taraweehText = "";
    [ObservableProperty] private string _rakahsText = "";
    [ObservableProperty] private string _tahajjudText = "";
    [ObservableProperty] private IReadOnlyList<RakahOption> _rakahs = [];
    [ObservableProperty] private IReadOnlyList<RamadanDay> _days = [];

    public RamadanViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    private static DateOnly Today => App.Instance.Today;

    public bool FastToday
    {
        get => App.Instance.Tracker.Day(Today).Fast;
        set => App.Instance.Tracker.SetFast(Today, value);
    }

    public bool Tahajjud
    {
        get => App.Instance.Tracker.Day(Today).Tahajjud;
        set => App.Instance.Tracker.SetTahajjud(Today, value);
    }

    [RelayCommand] private static void SetTaraweeh(int rakahs) => App.Instance.Tracker.SetTaraweeh(Today, rakahs);

    public void Reload()
    {
        var t = App.Instance.Tracker;
        var today = Today;
        var h = Ui.HijriOf(today);
        InRamadan = h.Month == 9;
        // The Ramadan to show: this one, else the last one; and the next one for the countdown.
        var shownYear = InRamadan || h.Month > 9 ? h.Year : h.Year - 1;
        var nextYear = h.Month < 9 ? h.Year : h.Year + 1;
        var start = Ui.FromHijri(shownYear, 9, 1);
        var len = Core.HijriDate.DaysInMonth(shownYear, 9);
        var nextStart = Ui.FromHijri(nextYear, 9, 1);
        var days = Enumerable.Range(0, len).Select(start.AddDays).ToList();
        var logs = days.Select(t.Day).ToList();

        if (InRamadan)
        {
            HeroTop = $"رمضان {Ui.D(h.Year)} هـ";
            HeroMain = $"اليوم {Ui.D(h.Day)} من {Ui.D(len)}";
            HeroSub = "";
            Progress = h.Day / (double)len;
        }
        else
        {
            HeroTop = $"رمضان {Ui.D(nextYear)} هـ";
            HeroMain = $"باقي {Occasions.Days(nextStart.DayNumber - today.DayNumber)}";
            HeroSub = $"يبدأ تقريبًا {Ui.Date(nextStart)}";
            Progress = 0;
        }
        TodayTitle = InRamadan ? "اليوم" : "قيام الليل";
        var qiyamMonth = 0;
        for (var d = new DateOnly(today.Year, today.Month, 1); d <= today; d = d.AddDays(1))
            if (t.Day(d).Tahajjud) qiyamMonth++;
        QiyamText = InRamadan ? "" : $"هذا الشهر: {Occasions.Nights(qiyamMonth)}";

        var todayLog = t.Day(today);
        Rakahs = RakahChoices.Select(r => new RakahOption(r, r == 0 ? "لم أصلِّ" : $"{Ui.D(r)} ركعة", todayLog.Taraweeh == r)).ToList();
        StatsTitle = $"إحصائية رمضان {Ui.D(shownYear)} هـ";
        FastedText = $"{Ui.D(logs.Count(d => d.Fast))}/{Ui.D(len)}";
        TaraweehText = Ui.D(logs.Count(d => d.Taraweeh > 0));
        RakahsText = $"ليالي التراويح • {Ui.D(logs.Sum(d => d.Taraweeh))} ركعة";
        TahajjudText = Ui.D(logs.Count(d => d.Tahajjud));
        Days = days.Select((d, i) =>
        {
            var l = logs[i];
            var icons = (l.Fast ? "🍽️" : "") + (l.Taraweeh > 0 ? "🕌" : "") + (l.Tahajjud ? "✨" : "");
            return new RamadanDay(Ui.D(i + 1), icons, (l.Fast ? 1 : 0) + (l.Taraweeh > 0 ? 1 : 0) + (l.Tahajjud ? 1 : 0), i >= 20, InRamadan && d == today);
        }).ToList();
        OnPropertyChanged(nameof(FastToday));
        OnPropertyChanged(nameof(Tahajjud));
    }
}

/// <summary>A white day (13–15) that can be marked as fasted once it has come.</summary>
public sealed partial class WhiteDayItem(DateOnly date, bool canMark) : ObservableObject
{
    public DateOnly Date { get; } = date;
    public string HijriDay => Ui.D(Ui.HijriOf(Date).Day);
    public string Gregorian => Ui.Date(Date);
    public string Subtitle => CanMark ? $"{Ui.Hijri(Date)} • هل صمته؟" : Ui.Hijri(Date);
    public bool CanMark { get; } = canMark;

    public bool Fasted
    {
        get => App.Instance.Tracker.Day(Date).Fast;
        set { if (CanMark) App.Instance.Tracker.SetFast(Date, value); OnPropertyChanged(); }
    }
}

public sealed record WhiteCell(bool Done, bool Started);
public sealed record WhiteMonthRow(string Month, IReadOnlyList<WhiteCell> Cells);

/// <summary>الأيام البيض: the 13th, 14th and 15th of each Hijri month.</summary>
public sealed partial class WhiteDaysViewModel : ObservableObject
{
    [ObservableProperty] private string _heroMain = "";
    [ObservableProperty] private string _heroSub = "";
    [ObservableProperty] private string _yearTitle = "";
    [ObservableProperty] private IReadOnlyList<WhiteDayItem> _next = [];
    [ObservableProperty] private IReadOnlyList<WhiteMonthRow> _months = [];

    public WhiteDaysViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    public void Reload()
    {
        var t = App.Instance.Tracker;
        var today = App.Instance.Today;
        var h = Ui.HijriOf(today);
        // This month's white days, or next month's once they have passed.
        int y = h.Year, m = h.Month;
        if (h.Day > 15 && ++m > 12) { m = 1; y++; }
        var next = new[] { 13, 14, 15 }.Select(d => Ui.FromHijri(y, m, d)).ToList();
        HeroMain = $"{Ui.D(13)}–{Ui.D(15)} {Core.HijriDate.MonthNameAr(m)}";
        HeroSub = next[0] == today ? "تبدأ اليوم" : next[0] > today ? $"بعد {Occasions.Days(next[0].DayNumber - today.DayNumber)}" : "الآن";
        Next = next.Select(d => new WhiteDayItem(d, d <= today)).ToList();

        var rows = new List<WhiteMonthRow>();
        var total = 0;
        for (var mm = 1; mm <= h.Month; mm++)
        {
            var ds = new[] { 13, 14, 15 }.Select(d => Ui.FromHijri(h.Year, mm, d)).ToList();
            var cells = ds.Select(d => new WhiteCell(t.Day(d).Fast, ds[0] <= today)).ToList();
            total += cells.Count(c => c.Done);
            rows.Add(new WhiteMonthRow(Core.HijriDate.MonthNameAr(mm), cells));
        }
        rows.Reverse();
        Months = rows;
        YearTitle = $"إحصائية {Ui.D(h.Year)} هـ • {Occasions.Days(total)}";
    }
}
