using System.Globalization;

namespace Mawaqeety.Core;

public readonly record struct HijriDate(int Year, int Month, int Day)
{
    private static readonly string[] MonthsAr =
    [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
        "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
    ];

    private static readonly string[] MonthsEn =
    [
        "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Ula", "Jumada al-Akhirah",
        "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qa'dah", "Dhu al-Hijjah",
    ];

    /// <summary>Umm al-Qura Hijri date, with an optional day correction (local moon-sighting may differ by ±1–2 days).</summary>
    public static HijriDate From(DateOnly date, int dayAdjustment = 0)
    {
        var dt = date.ToDateTime(TimeOnly.MinValue).AddDays(dayAdjustment);
        try
        {
            var cal = new UmAlQuraCalendar();
            return new HijriDate(cal.GetYear(dt), cal.GetMonth(dt), cal.GetDayOfMonth(dt));
        }
        catch (ArgumentOutOfRangeException)
        {
            var cal = new HijriCalendar();
            return new HijriDate(cal.GetYear(dt), cal.GetMonth(dt), cal.GetDayOfMonth(dt));
        }
    }

    public string MonthName(bool arabic) => (arabic ? MonthsAr : MonthsEn)[Month - 1];

    /// <summary>Arabic name of a Hijri month (1..12).</summary>
    public static string MonthNameAr(int month) => MonthsAr[(month - 1 + 120) % 12];

    /// <summary>
    /// The local day of a Hijri date: the inverse of <see cref="From"/> with the same day adjustment
    /// (Umm al-Qura; day 30 of a 29-day month is the 1st of the next month).
    /// </summary>
    public static DateOnly ToGregorian(int year, int month, int day, int dayAdjustment = 0)
    {
        while (month > 12) { month -= 12; year++; }
        while (month < 1) { month += 12; year--; }
        var extra = Math.Max(0, day - DaysInMonth(year, month));
        day -= extra;
        DateTime dt;
        try { dt = new UmAlQuraCalendar().ToDateTime(year, month, day, 0, 0, 0, 0); }
        catch (ArgumentOutOfRangeException) { dt = new HijriCalendar().ToDateTime(year, month, day, 0, 0, 0, 0); }
        return DateOnly.FromDateTime(dt).AddDays(extra - dayAdjustment);
    }

    /// <summary>Days in a Hijri month (29 or 30).</summary>
    public static int DaysInMonth(int year, int month)
    {
        try { return new UmAlQuraCalendar().GetDaysInMonth(year, month); }
        catch (ArgumentOutOfRangeException) { return new HijriCalendar().GetDaysInMonth(year, month); }
    }

    public string ToDisplay(bool arabic) => arabic
        ? $"{Day} {MonthName(true)} {Year} هـ"
        : $"{Day} {MonthName(false)} {Year} AH";
}
