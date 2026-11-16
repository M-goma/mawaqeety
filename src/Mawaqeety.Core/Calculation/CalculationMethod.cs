namespace Mawaqeety.Core.Calculation;

public enum MethodId
{
    Egyptian, MuslimWorldLeague, UmmAlQura, Karachi, Isna, Dubai, Kuwait, Qatar, Gulf,
    Singapore, Turkey, France, Russia, Morocco, Algeria, Tunisia, Jordan, Tehran, Jafari, Custom,
}

public enum AsrMadhab { Shafii = 1, Hanafi = 2 }

public enum HighLatitudeRule { None, AngleBased, OneSeventh, MiddleOfNight }

/// <summary>
/// Parameters of a prayer-time convention. Fajr/Isha are sun-depression angles in degrees below the horizon,
/// unless IshaMinutes is set (Isha = Maghrib + minutes). Maghrib is sunset unless MaghribAngle/MaghribMinutes are set.
/// </summary>
public sealed record CalculationMethod(
    MethodId Id,
    string NameEn,
    string NameAr,
    double FajrAngle,
    double? IshaAngle,
    int? IshaMinutes = null,
    double? MaghribAngle = null,
    int MaghribMinutes = 0,
    int? IshaMinutesInRamadan = null)
{
    public static readonly IReadOnlyList<CalculationMethod> All =
    [
        new(MethodId.Egyptian, "Egyptian General Authority of Survey", "الهيئة المصرية العامة للمساحة", 19.5, 17.5),
        new(MethodId.MuslimWorldLeague, "Muslim World League", "رابطة العالم الإسلامي", 18, 17),
        new(MethodId.UmmAlQura, "Umm Al-Qura University, Makkah", "جامعة أم القرى - مكة المكرمة", 18.5, null, IshaMinutes: 90, IshaMinutesInRamadan: 120),
        new(MethodId.Karachi, "University of Islamic Sciences, Karachi", "جامعة العلوم الإسلامية - كراتشي", 18, 18),
        new(MethodId.Isna, "Islamic Society of North America (ISNA)", "الجمعية الإسلامية لأمريكا الشمالية", 15, 15),
        new(MethodId.Dubai, "Dubai (UAE)", "دبي - الإمارات", 18.2, 18.2),
        new(MethodId.Kuwait, "Kuwait", "الكويت", 18, 17.5),
        new(MethodId.Qatar, "Qatar", "قطر", 18, null, IshaMinutes: 90),
        new(MethodId.Gulf, "Gulf Region", "منطقة الخليج", 19.5, null, IshaMinutes: 90),
        new(MethodId.Singapore, "Singapore / Malaysia / Indonesia", "سنغافورة / ماليزيا / إندونيسيا", 20, 18),
        new(MethodId.Turkey, "Diyanet, Turkey", "رئاسة الشؤون الدينية - تركيا", 18, 17),
        new(MethodId.France, "UOIF, France", "اتحاد المنظمات الإسلامية - فرنسا", 12, 12),
        new(MethodId.Russia, "Spiritual Administration of Muslims of Russia", "الإدارة الدينية لمسلمي روسيا", 16, 15),
        new(MethodId.Morocco, "Ministry of Habous, Morocco", "وزارة الأوقاف - المغرب", 19, 17),
        new(MethodId.Algeria, "Ministry of Religious Affairs, Algeria", "وزارة الشؤون الدينية - الجزائر", 18, 17),
        new(MethodId.Tunisia, "Ministry of Religious Affairs, Tunisia", "وزارة الشؤون الدينية - تونس", 18, 18),
        new(MethodId.Jordan, "Ministry of Awqaf, Jordan", "وزارة الأوقاف - الأردن", 18, 18),
        new(MethodId.Tehran, "Institute of Geophysics, University of Tehran", "معهد الجيوفيزياء - جامعة طهران", 17.7, 14, MaghribAngle: 4.5),
        new(MethodId.Jafari, "Shia Ithna-Ashari, Leva Institute, Qum", "الشيعة الإثنا عشرية - معهد ليفا، قم", 16, 14, MaghribAngle: 4),
        new(MethodId.Custom, "Custom angles", "زوايا مخصصة", 18, 17),
    ];

    public static CalculationMethod Get(MethodId id) => All.First(m => m.Id == id);

    public static CalculationMethod Custom(double fajrAngle, double ishaAngle) =>
        Get(MethodId.Custom) with { FajrAngle = fajrAngle, IshaAngle = ishaAngle };

    /// <summary>Officially used / most common convention for a country (ISO 3166 alpha-2).</summary>
    public static MethodId DefaultForCountry(string? countryCode) => (countryCode ?? "").ToUpperInvariant() switch
    {
        "EG" or "SD" or "SS" or "LY" or "SY" or "LB" or "IQ" or "PS" or "YE" => MethodId.Egyptian,
        "SA" => MethodId.UmmAlQura,
        "AE" => MethodId.Dubai,
        "KW" => MethodId.Kuwait,
        "QA" => MethodId.Qatar,
        "BH" or "OM" => MethodId.Gulf,
        "JO" => MethodId.Jordan,
        "MA" => MethodId.Morocco,
        "DZ" => MethodId.Algeria,
        "TN" => MethodId.Tunisia,
        "TR" => MethodId.Turkey,
        "FR" or "BE" => MethodId.France,
        "RU" => MethodId.Russia,
        "IR" => MethodId.Tehran,
        "PK" or "IN" or "BD" or "AF" => MethodId.Karachi,
        "MY" or "SG" or "ID" or "BN" => MethodId.Singapore,
        "US" or "CA" => MethodId.Isna,
        _ => MethodId.MuslimWorldLeague,
    };

    public static AsrMadhab DefaultMadhabForCountry(string? countryCode) => (countryCode ?? "").ToUpperInvariant() switch
    {
        "PK" or "IN" or "BD" or "AF" => AsrMadhab.Hanafi,
        _ => AsrMadhab.Shafii,
    };
}
