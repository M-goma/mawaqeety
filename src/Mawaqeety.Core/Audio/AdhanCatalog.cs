namespace Mawaqeety.Core.Audio;

public sealed record AdhanVoice(string Id, string NameAr, string NameEn, string FileName, bool IsFajr)
{
    public string Url => AdhanCatalog.BaseUrl + Uri.EscapeDataString(FileName);
    public string DisplayName(bool arabic) => arabic ? NameAr : NameEn;
}

/// <summary>
/// Adhan recordings offered in the app. They are NOT bundled with the installer: each one is downloaded
/// on demand from a public collection (github.com/Kiwifu/adhan-mp3) and cached locally for offline use.
/// The rights to these recordings belong to their owners — confirm licensing before commercial distribution.
/// </summary>
public static class AdhanCatalog
{
    public const string BaseUrl = "https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/";

    public const string DefaultId = "alafasy";
    public const string DefaultFajrId = "alafasy-fajr";

    public static readonly IReadOnlyList<AdhanVoice> All =
    [
        new("alafasy", "مشاري راشد العفاسي", "Mishary Rashid Alafasy", "Mishary_Rashid_Alafasy_1_-_Kuwait_(مشاري_راشد_العفاسي_-_الكويت).mp3", false),
        new("makkah-mala", "الحرم المكي - علي بن أحمد ملا", "Makkah - Ali Ahmad Mulla", "Ali_Ibn_Ahmad_Mala_1_-_Al_Haram_Al_Maki_(علي_بن_أحمد_ملا_-_الحرم_المكي).mp3", false),
        new("madinah", "الحرم المدني", "Al-Masjid an-Nabawi (Madinah)", "Adhan_Al_Haram_Al_Madani_-_Al_Madinah_1_(أذان_الحرم_المدني_-_المدينة_المنورة).mp3", false),
        new("aqsa", "المسجد الأقصى", "Al-Aqsa Mosque", "Adhan_Al_Aqsa_-_Jerusalem_(أذان_المسجد_الأقصى_-_القدس).mp3", false),
        new("abdulbasit", "عبد الباسط عبد الصمد", "Abdul Basit Abdus Samad", "Abdulbasit_Abdusamad_1_-_Egypt_(عبد_الباسط_عبد_الصمد_-_مصر).mp3", false),
        new("refaat", "محمد رفعت", "Muhammad Refaat", "Muhammad_Refaat_-_Cairo_(محمد_رفعت_-_القاهرة).mp3", false),
        new("hussary", "محمود خليل الحصري", "Mahmoud Khalil Al-Hussary", "Mahmoud_Khalil_Al_Hussary_-_Cairo_(محمود_خليل_الحصري_-_القاهرة).mp3", false),
        new("minshawi", "محمد صديق المنشاوي", "Mohamed Siddiq El-Minshawi", "Mohamed_Siddiq_El-Minshawi_-_Egypt_1_(محمد_صديق_المنشاوي_-_مصر).mp3", false),
        new("banna", "محمود علي البنا", "Mahmoud Ali Al-Banna", "Mahmoud_Ali_Al_Banna_-_Cairo_(محمود_علي_البنا_-_القاهرة).mp3", false),
        new("mustafa-ismail", "مصطفى إسماعيل", "Mustafa Ismail", "Mustafa_Ismail_-_Egypt_(مصطفى_إسماعيل_-_مصر).mp3", false),
        new("qatami", "ناصر القطامي", "Nasser Al-Qatami", "Nasser_Al_Qatami_1_-_Saudi_Arabia_(ناصر_القطامي_-_المملكة_العربية_السعودية).mp3", false),
        // Fajr adhans include "الصلاة خير من النوم"
        new("alafasy-fajr", "أذان الفجر - مشاري العفاسي", "Fajr - Mishary Alafasy", "Mishary_Rashid_Alafasy_3_-_Fajr_Kuwait_(مشاري_راشد_العفاسي_-_فجر_الكويت).mp3", true),
        new("makkah-fajr", "أذان الفجر - الحرم المكي", "Fajr - Masjid al-Haram (Makkah)", "Adhan_Fajr_Al_Haram_Al_Maki_(أذان_الفجر_الحرم_المكي).mp3", true),
        new("madinah-fajr", "أذان الفجر - الحرم المدني", "Fajr - Al-Masjid an-Nabawi", "Adhan_Fajr_Al_Haram_Al_Madani_(أذان_الفجر_الحرم_المدني).mp3", true),
        new("cairo-fajr", "أذان الفجر - القاهرة", "Fajr - Cairo", "Adhan_Fajr_Cairo_Egypt_(أذان_الفجر_القاهرة_مصر).mp3", true),
    ];

    public static AdhanVoice? Find(string? id) => All.FirstOrDefault(v => v.Id == id);

    /// <summary>Fajr list shows the Fajr-specific recordings first, then the regular ones.</summary>
    public static IEnumerable<AdhanVoice> ForFajr => All.Where(v => v.IsFajr).Concat(All.Where(v => !v.IsFajr));
    public static IEnumerable<AdhanVoice> Regular => All.Where(v => !v.IsFajr);
}
