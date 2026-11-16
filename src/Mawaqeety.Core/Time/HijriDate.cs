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

    public string ToDisplay(bool arabic) => arabic
        ? $"{Day} {MonthName(true)} {Year} هـ"
        : $"{Day} {MonthName(false)} {Year} AH";
}
