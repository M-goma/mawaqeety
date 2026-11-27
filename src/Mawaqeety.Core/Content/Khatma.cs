using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Content;

/// <summary>
/// The Quran wird and khatma plan, kept in <see cref="AppSettings"/> (the same rules as the mobile app's
/// AppState: khatmaDaily / khatmaDay / khatmaTarget / _noteQuranPage).
/// </summary>
public static class Khatma
{
    public const int Pages = MushafIndex.PageCount;
    public static readonly int[] Plans = [7, 10, 15, 20, 30, 60];

    public static string Key(DateOnly d) => d.ToString("yyyy-MM-dd");

    /// <summary>«أسبوع»، «١٠ يومًا»، «شهر»، «شهران».</summary>
    public static string PlanLabel(int days) => days switch
    {
        7 => "أسبوع",
        30 => "شهر",
        60 => "شهران",
        _ => $"{QuranRepository.ArabicDigits(days)} يومًا",
    };

    /// <summary>Pages per day of the current plan (0 = no plan).</summary>
    public static int Daily(AppSettings s) => s.KhatmaDays <= 0 ? 0 : (int)Math.Ceiling(Pages / (double)s.KhatmaDays);

    public static int DailyFor(int days) => (int)Math.Ceiling(Pages / (double)days);

    /// <summary>Day of the plan (1 = the day it started).</summary>
    public static int Day(AppSettings s, DateOnly today) =>
        DateOnly.TryParseExact(s.KhatmaStart, "yyyy-MM-dd", out var start) ? today.DayNumber - start.DayNumber + 1 : 1;

    /// <summary>The page the reader should reach by the end of today.</summary>
    public static int Target(AppSettings s, DateOnly today) => Math.Clamp(Daily(s) * Day(s, today), 0, Pages);

    /// <summary>Distinct Mushaf pages opened today.</summary>
    public static int PagesToday(AppSettings s, DateOnly today) => s.QuranDay == Key(today) ? s.QuranPages.Count : 0;

    /// <summary>Pages still to read today to be on the plan.</summary>
    public static int Behind(AppSettings s, DateOnly today) => Math.Clamp(Target(s, today) - s.KhatmaPage, 0, Pages);

    public static void Start(AppSettings s, int days, DateOnly today)
    {
        s.KhatmaDays = days;
        s.KhatmaStart = Key(today);
        s.KhatmaPage = 0;
    }

    public static void Stop(AppSettings s)
    {
        s.KhatmaDays = 0;
        s.KhatmaPage = 0;
    }

    /// <summary>True when <see cref="NotePage"/> would change anything (so the caller can skip saving).</summary>
    public static bool WouldChange(AppSettings s, DateOnly today, int page) =>
        s.QuranDay != Key(today) || !s.QuranPages.Contains(page) || (s.KhatmaDays > 0 && page > s.KhatmaPage);

    /// <summary>
    /// A Mushaf page was shown: counts it for today and moves the khatma on. The last page after reading most of
    /// the Mushaf in order (not a jump to the end) completes the khatma, and the next one starts.
    /// Returns the number of pages read today.
    /// </summary>
    public static int NotePage(AppSettings s, DateOnly today, int page)
    {
        var key = Key(today);
        if (s.QuranDay != key)
        {
            s.QuranDay = key;
            s.QuranPages = [];
        }
        if (!s.QuranPages.Contains(page)) s.QuranPages = [.. s.QuranPages, page];
        if (s.KhatmaDays > 0 && page > s.KhatmaPage)
        {
            var complete = page == Pages && s.KhatmaPage >= 560;
            s.KhatmaPage = page;
            if (complete)
            {
                s.KhatmaDone++;
                s.KhatmaPage = 0;
                s.KhatmaStart = key;
            }
        }
        return s.QuranPages.Count;
    }
}

/// <summary>Zakat on money, gold, silver and trade goods: 2.5% once the nisab is reached (and a Hijri year has passed).</summary>
public static class Zakat
{
    public const double GoldNisabGrams = 85, SilverNisabGrams = 595, Rate = 0.025;

    public sealed record Input(double Cash = 0, double Owed = 0, double Trade = 0, double Gold24 = 0, double Gold21 = 0,
        double Gold18 = 0, double Silver = 0, double Debts = 0);

    public sealed record Result(double Total, double Nisab, bool PricesKnown, bool Due, double Amount);

    /// <summary>Gold of every karat as grams of 24k.</summary>
    public static double PureGold(Input i) => i.Gold24 + i.Gold21 * 21 / 24 + i.Gold18 * 18 / 24;

    public static Result Compute(Input i, double goldPrice, double silverPrice, bool bySilver)
    {
        var total = i.Cash + i.Owed + i.Trade + PureGold(i) * goldPrice + i.Silver * silverPrice - i.Debts;
        var nisab = bySilver ? SilverNisabGrams * silverPrice : GoldNisabGrams * goldPrice;
        var known = nisab > 0;
        var due = known && total >= nisab;
        return new Result(total, nisab, known, due, due ? total * Rate : 0);
    }

    /// <summary>A number typed with Latin or Arabic digits ("1,250.5", "١٢٥٠٫٥"); 0 when empty or invalid.</summary>
    public static double Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return 0;
        var t = Sabeel.LatinDigits(text).Replace(",", "").Replace("٬", "").Replace('٫', '.').Trim();
        return double.TryParse(t, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var v) ? v : 0;
    }

    /// <summary>"12,345.67" with Arabic-Indic digits.</summary>
    public static string Money(double v)
    {
        var s = v.ToString("#,##0.##", System.Globalization.CultureInfo.InvariantCulture);
        return string.Concat(s.Select(c => c is >= '0' and <= '9' ? (char)('٠' + (c - '0')) : c));
    }
}
