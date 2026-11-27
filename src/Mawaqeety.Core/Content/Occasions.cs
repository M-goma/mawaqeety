namespace Mawaqeety.Core.Content;

public enum OccasionKind { Fast, Event, Season, NoFast }

/// <summary>An Islamic occasion by Hijri date, with the sahih hadith about it. <see cref="Days"/>: how many days it lasts.</summary>
public sealed record Occasion(string Id, int Month, int Day, string Name, OccasionKind Kind, int Days = 1, string Note = "", string Ref = "")
{
    public bool IsFast => Kind == OccasionKind.Fast;

    public string Emoji => Kind switch
    {
        OccasionKind.Fast => "🍽️", OccasionKind.Event => "🌙", OccasionKind.Season => "✨", _ => "🎉",
    };
}

/// <summary>
/// Islamic occasions and the sunnah fasts (the same list as the mobile app's lib/data/occasions.dart; hadith numbers
/// checked against the bundled Sahih al-Bukhari and Sahih Muslim).
/// </summary>
public static class Occasions
{
    public static readonly IReadOnlyList<Occasion> All =
    [
        new("newyear", 1, 1, "رأس السنة الهجرية", OccasionKind.Event, Note: "بداية عام هجري جديد"),
        new("tasua", 1, 9, "صيام تاسوعاء", OccasionKind.Fast,
            Note: "«لئن بقيتُ إلى قابلٍ لأصومنّ التاسع»", Ref: "صحيح مسلم ١١٣٤"),
        new("ashura", 1, 10, "صيام عاشوراء", OccasionKind.Fast,
            Note: "«صيام يوم عاشوراء أحتسب على الله أن يكفّر السنة التي قبله»", Ref: "صحيح مسلم ١١٦٢"),
        new("ramadan", 9, 1, "بداية شهر رمضان", OccasionKind.Event, Days: 30, Note: "شهر الصيام والقيام والقرآن"),
        new("lastten", 9, 21, "العشر الأواخر وليلة القدر", OccasionKind.Season, Days: 10,
            Note: "«تحرّوا ليلة القدر في الوتر من العشر الأواخر من رمضان»", Ref: "صحيح البخاري ٢٠١٧"),
        new("fitr", 10, 1, "عيد الفطر", OccasionKind.NoFast,
            Note: "نهى النبي ﷺ عن صيام يوم الفطر ويوم الأضحى", Ref: "صحيح مسلم ١١٣٨"),
        new("shawwal", 10, 2, "ستٌّ من شوال", OccasionKind.Fast, Days: 28,
            Note: "«من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر»", Ref: "صحيح مسلم ١١٦٤"),
        new("dhulhijja", 12, 1, "العشر من ذي الحجة", OccasionKind.Season, Days: 10,
            Note: "«ما العمل في أيامٍ العشر أفضل من العمل في هذه»", Ref: "صحيح البخاري ٩٦٩"),
        new("arafah", 12, 9, "صيام يوم عرفة", OccasionKind.Fast,
            Note: "«صيام يوم عرفة أحتسب على الله أن يكفّر السنة التي قبله والسنة التي بعده»", Ref: "صحيح مسلم ١١٦٢"),
        new("adha", 12, 10, "عيد الأضحى", OccasionKind.NoFast,
            Note: "نهى النبي ﷺ عن صيام يوم الفطر ويوم الأضحى", Ref: "صحيح مسلم ١١٣٨"),
        new("tashreeq", 12, 11, "أيام التشريق", OccasionKind.NoFast, Days: 3,
            Note: "«أيام التشريق أيام أكلٍ وشرب»", Ref: "صحيح مسلم ١١٤١"),
    ];

    public const string MonThuNote = "سُئل ﷺ عن صوم يوم الاثنين فقال: «ذاك يومٌ وُلدتُ فيه، ويومٌ بُعثتُ أو أُنزل عليّ فيه»";
    public const string MonThuRef = "صحيح مسلم ١١٦٢";

    /// <summary>The start of the next (or current) occurrence of <paramref name="o"/> on or after <paramref name="from"/>.</summary>
    public static DateOnly Next(Occasion o, DateOnly from, int hijriAdjustment = 0)
    {
        var h = HijriDate.From(from, hijriAdjustment);
        for (var y = h.Year; y <= h.Year + 1; y++)
        {
            var start = HijriDate.ToGregorian(y, o.Month, o.Day, hijriAdjustment);
            if (start.AddDays(o.Days - 1) >= from) return start;
        }
        return HijriDate.ToGregorian(h.Year + 1, o.Month, o.Day, hijriAdjustment);
    }

    /// <summary>The voluntary fast that falls on <paramref name="d"/>: an occasion, the six of Shawwal, the white days, or Monday/Thursday.</summary>
    public static string? SunnahFastOn(DateOnly d, int hijriAdjustment = 0)
    {
        var h = HijriDate.From(d, hijriAdjustment);
        foreach (var o in All.Where(o => o.IsFast && o.Id != "shawwal"))
            if (h.Month == o.Month && h.Day == o.Day) return o.Name;
        if (h.Month == 10 && h.Day >= 2) return "ستٌّ من شوال";
        if (h.Month != 9 && h.Day is >= 13 and <= 15) return "الأيام البيض";
        if (h.Month != 9 && d.DayOfWeek == DayOfWeek.Monday) return "صيام الاثنين";
        if (h.Month != 9 && d.DayOfWeek == DayOfWeek.Thursday) return "صيام الخميس";
        return null;
    }

    /// <summary>«اليوم»، «غدًا»، «بعد يومين»، «بعد ٥ أيام»، «بعد ٢٠ يومًا».</summary>
    public static string InDays(int n) => n switch
    {
        0 => "اليوم",
        1 => "غدًا",
        2 => "بعد يومين",
        <= 10 => $"بعد {QuranRepository.ArabicDigits(n)} أيام",
        _ => $"بعد {QuranRepository.ArabicDigits(n)} يومًا",
    };

    /// <summary>«يوم واحد»، «يومان»، «٥ أيام»، «٢٠ يومًا».</summary>
    public static string Days(int n) => n switch
    {
        1 => "يوم واحد",
        2 => "يومان",
        >= 3 and <= 10 => $"{QuranRepository.ArabicDigits(n)} أيام",
        _ => $"{QuranRepository.ArabicDigits(n)} يومًا",
    };

    /// <summary>«ليلة واحدة»، «ليلتان»، «٥ ليالٍ»، «٢٠ ليلة».</summary>
    public static string Nights(int n) => n switch
    {
        1 => "ليلة واحدة",
        2 => "ليلتان",
        >= 3 and <= 10 => $"{QuranRepository.ArabicDigits(n)} ليالٍ",
        _ => $"{QuranRepository.ArabicDigits(n)} ليلة",
    };

    /// <summary>«صفحة واحدة»، «صفحتان»، «٥ صفحات»، «٢٠ صفحة».</summary>
    public static string Pages(int n) => n switch
    {
        1 => "صفحة واحدة",
        2 => "صفحتان",
        >= 3 and <= 10 => $"{QuranRepository.ArabicDigits(n)} صفحات",
        _ => $"{QuranRepository.ArabicDigits(n)} صفحة",
    };
}
