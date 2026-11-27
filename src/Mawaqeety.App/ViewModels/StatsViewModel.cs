using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.App.ViewModels;

public sealed record BarItem(string Label, double Value, string ValueText, bool IsToday);
public sealed record ShareItem(string Label, double Value, string ValueText, string Color);
public sealed record MonthCell(string Text, double Value, bool IsToday, bool IsFuture, bool IsBlank);

/// <summary>Statistics to encourage completing each day.</summary>
public sealed partial class StatsViewModel : ObservableObject
{
    private static readonly string[] WeekDays = ["الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"];
    private static readonly string[] Months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
    private static readonly string[] Quotes =
    [
        "«صلاةُ الجماعةِ تَفضُلُ صلاةَ الفذِّ بسبعٍ وعشرين درجة» — متفق عليه",
        "«أحبُّ الأعمالِ إلى اللهِ أدومُها وإن قلّ» — متفق عليه",
        "«مَن صلّى العشاءَ في جماعةٍ فكأنما قام نصفَ الليل، ومَن صلّى الصبحَ في جماعةٍ فكأنما صلّى الليلَ كلَّه» — رواه مسلم",
        "«كلمتان خفيفتان على اللسان، ثقيلتان في الميزان: سبحان الله وبحمده، سبحان الله العظيم» — متفق عليه",
        "«ألا بذكرِ اللهِ تطمئنُّ القلوب» — الرعد ٢٨",
    ];

    [ObservableProperty] private bool _isMonth;
    [ObservableProperty] private IReadOnlyList<BarItem> _week = [];
    [ObservableProperty] private IReadOnlyList<ShareItem> _shares = [];
    [ObservableProperty] private IReadOnlyList<MonthCell> _monthCells = [];
    [ObservableProperty] private string _monthTitle = "";
    [ObservableProperty] private string _prayersTitle = "";
    [ObservableProperty] private bool _hasPrayers;
    [ObservableProperty] private string _prayersStreak = "";
    [ObservableProperty] private string _fajrStreak = "";
    [ObservableProperty] private string _morningStreak = "";
    [ObservableProperty] private string _tasbeehText = "";
    [ObservableProperty] private string _quote = "";
    [ObservableProperty] private string _sunanText = "";
    [ObservableProperty] private string _pagesText = "";

    public StatsViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    partial void OnIsMonthChanged(bool value) => Reload();
    [RelayCommand] private void ShowWeek() => IsMonth = false;
    [RelayCommand] private void ShowMonth() => IsMonth = true;

    private static string D(int n) => QuranRepository.ArabicDigits(n);

    public void Reload()
    {
        var t = App.Instance.Tracker;
        var today = App.Instance.Today;
        var from = IsMonth ? new DateOnly(today.Year, today.Month, 1) : today.AddDays(-6);

        Week = Enumerable.Range(0, 7).Select(i => today.AddDays(i - 6)).Select(d =>
        {
            var v = t.Completion(d);
            return new BarItem(WeekDays[((int)d.DayOfWeek + 6) % 7], v, v > 0 ? D((int)Math.Round(v * 100)) + "٪" : "", d == today);
        }).ToList();

        var first = new DateOnly(today.Year, today.Month, 1);
        var lead = (int)first.DayOfWeek; // Sunday first
        var cells = Enumerable.Range(0, lead).Select(_ => new MonthCell("", 0, false, false, true)).ToList();
        for (var d = first; d.Month == today.Month; d = d.AddDays(1))
            cells.Add(new MonthCell(D(d.Day), d > today ? 0 : t.Completion(d), d == today, d > today, false));
        MonthCells = cells;
        MonthTitle = $"{Months[today.Month - 1]} {D(today.Year)}";

        var dist = t.Distribution(from, today);
        var total = dist.Values.Sum();
        HasPrayers = total > 0;
        PrayersTitle = $"صلواتك المسجّلة ({D(total)} صلاة)";
        var colors = new Dictionary<PrayerLog, string> { [PrayerLog.Mosque] = "#12A372", [PrayerLog.Jamaah] = "#3B82F6", [PrayerLog.Alone] = "#D4AF37", [PrayerLog.Qada] = "#E57373" };
        Shares = dist.Select(kv => new ShareItem($"{kv.Key.Emoji()} {kv.Key.Label()}", total == 0 ? 0 : kv.Value / (double)total,
            total == 0 ? "" : D((int)Math.Round(kv.Value * 100.0 / total)) + "٪", colors[kv.Key])).ToList();

        PrayersStreak = $"🔥 {D(t.PrayersStreak(today))}";
        FajrStreak = $"🕌 {D(t.FajrMosqueStreak(today))}";
        MorningStreak = $"☀️ {D(t.MorningStreak(today))}";
        TasbeehText = $"📿 {D(t.TasbeehBetween(from, today))} تسبيحة {(IsMonth ? "هذا الشهر" : "في آخر ٧ أيام")}";
        Quote = Quotes[today.Day % Quotes.Length];

        int sunan = 0, pages = 0, days = 0;
        for (var d = from; d <= today; d = d.AddDays(1))
        {
            sunan += t.Day(d).SunanDone;
            pages += t.Day(d).Pages;
            days++;
        }
        SunanText = $"✨ {D(sunan)} من {D(days * Enum.GetValues<Sunnah>().Length)} سنة • الرواتب والضحى والوتر";
        PagesText = $"📖 {Occasions.Pages(pages)} قرأتها من المصحف";
    }
}
