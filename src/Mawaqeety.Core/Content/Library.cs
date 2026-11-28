using System.Text.Json;
using System.Text.Json.Serialization;

namespace Mawaqeety.Core.Content;

/// <summary>Finds a hadith of the bundled Sahihs by its common number (and, when known, its row in the data file).</summary>
public static class SahihLookup
{
    public static string CollectionName(string id) => id == "bukhari" ? "صحيح البخاري" : "صحيح مسلم";

    public static Hadith? Find(string collection, int number, int index = -1, string? contains = null)
    {
        var c = HadithCollection.Load(collection);
        if (index >= 0 && index < c.All.Count && c.All[index].Number == number) return c.All[index];
        var same = c.All.Where(h => h.Number == number).ToList();
        if (same.Count == 0) return null;
        if (!string.IsNullOrEmpty(contains))
        {
            var q = HadithCollection.Plain(contains);
            if (same.FirstOrDefault(h => HadithCollection.Plain(h.Text).Contains(q)) is { } hit) return hit;
        }
        return same[0];
    }
}

// ============================================================ الأربعون النووية (arbaeen.json, same file as the mobile app)

public sealed record SahihRef([property: JsonPropertyName("c")] string Collection, [property: JsonPropertyName("n")] int Number,
    [property: JsonPropertyName("i")] int Index)
{
    public string Name => SahihLookup.CollectionName(Collection);
    public Hadith? Resolve() => SahihLookup.Find(Collection, Number, Index);
}

public sealed record ArbaeenExtra(string Label, string Text, string? Takhrij);

public sealed record ArbaeenHadith(
    [property: JsonPropertyName("n")] int Number, string Title, string Narrator, string Text, string Takhrij,
    string? Grade, ArbaeenExtra? Extra, string? Note, string? IsnadNote,
    IReadOnlyList<SahihRef>? Sahih, IReadOnlyList<SahihRef>? Related, IReadOnlyList<string>? Benefits, string? BenefitsUrl)
{
    /// <summary>Plain text for copying: the hadith, the extra narration and the takhrij.</summary>
    public string CopyText => Text + (Extra is { } e ? $"\n\n{e.Label}: {e.Text}" : "") + $"\n\n[{Takhrij}]";
}

public sealed record ArbaeenBook(string Title, string Author, IReadOnlyList<string> About, string AboutSource,
    IReadOnlyDictionary<string, string> Sources, IReadOnlyList<ArbaeenHadith> Hadiths)
{
    private static readonly Lazy<ArbaeenBook> _default = new(() => Res.Load<ArbaeenBook>("arbaeen.json"));
    public static ArbaeenBook Default => _default.Value;

    private static readonly string[] Ordinals = ["الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس", "السابع", "الثامن", "التاسع", "العاشر"];

    /// <summary>«الأول» … «الثاني والأربعون» (same as the mobile app).</summary>
    public static string Ordinal(int n)
    {
        if (n <= 10) return Ordinals[n - 1];
        if (n == 11) return "الحادي عشر";
        if (n == 12) return "الثاني عشر";
        if (n < 20) return $"{Ordinals[n - 11]} عشر";
        var tens = (n / 10 * 10) switch { 20 => "العشرون", 30 => "الثلاثون", _ => "الأربعون" };
        var u = n % 10;
        return u == 0 ? tens : $"{(u == 1 ? "الحادي" : Ordinals[u - 1])} و{tens}";
    }
}

// ============================================================ فقه العبادات المختصر (fiqh.json)

public sealed record FiqhAnswer(string Source, string Ref, string Url, string Text);

public sealed record FiqhItem(int Id, string Topic, string Sub, [property: JsonPropertyName("q")] string Question, bool Khilaf,
    IReadOnlyList<FiqhAnswer> Answers)
{
    private string? _key;
    private string Key => _key ??= SearchKey($"{Question} {Sub} {string.Join(' ', Answers.Select(a => a.Text))}");

    /// <summary>Search key like the mobile app: diacritics and letter forms unified, alefs dropped.</summary>
    public static string SearchKey(string s) => HadithCollection.Plain(s).ToLowerInvariant().Replace("ا", "").Trim();

    /// <summary>Every word of the query appears in the question, sub-topic or answers.</summary>
    public bool Matches(string query) =>
        SearchKey(query).Split(' ', StringSplitOptions.RemoveEmptyEntries).All(Key.Contains);
}

public sealed record FiqhSource(string Name, string Desc, string Url);

public sealed record FiqhBook(string Title, string Collected, string Note, IReadOnlyList<FiqhSource> Sources, IReadOnlyList<FiqhItem> Items)
{
    private static readonly Lazy<FiqhBook> _default = new(() => Res.Load<FiqhBook>("fiqh.json"));
    public static FiqhBook Default => _default.Value;

    /// <summary>Topics in their order of first appearance.</summary>
    public IReadOnlyList<string> Topics => Items.Select(i => i.Topic).Distinct().ToList();

    public IEnumerable<FiqhItem> Filter(string? topic, string query) =>
        Items.Where(i => (topic is null || i.Topic == topic) && (string.IsNullOrWhiteSpace(query) || i.Matches(query)));
}

// ============================================================ أسباب النزول (asbab.json, built by tools/build_asbab.py)

/// <summary>A sahih occasion of revelation: a narration in al-Bukhari or Muslim saying ayat From–To of Surah came down for an event.</summary>
public sealed record Sabab(int Surah, int From, int To, string Collection, int Number, int Index, string Excerpt)
{
    public string CollectionName => SahihLookup.CollectionName(Collection);
    public string Ref => $"{CollectionName} {QuranRepository.ArabicDigits(Number)}";
    public string AyahLabel => From == To ? $"الآية {QuranRepository.ArabicDigits(From)}"
        : $"الآيات {QuranRepository.ArabicDigits(From)}–{QuranRepository.ArabicDigits(To)}";
    public Hadith? Hadith() => SahihLookup.Find(Collection, Number, Index);
}

public sealed class Asbab
{
    private static readonly Lazy<Asbab> _default = new(() => new Asbab());
    public static Asbab Default => _default.Value;

    public IReadOnlyList<Sabab> All { get; }
    private readonly Dictionary<int, List<Sabab>> _bySurah;

    private Asbab()
    {
        using var s = Res.Open("asbab.json");
        using var doc = JsonDocument.Parse(s);
        All = doc.RootElement.GetProperty("a").EnumerateArray().Select(r => new Sabab(
            r.GetProperty("s").GetInt32(), r.GetProperty("f").GetInt32(), r.GetProperty("t").GetInt32(),
            r.GetProperty("c").GetString()!, r.GetProperty("n").GetInt32(), r.GetProperty("i").GetInt32(),
            r.GetProperty("x").GetString()!)).ToList();
        _bySurah = All.GroupBy(a => a.Surah).ToDictionary(g => g.Key, g => g.ToList());
    }

    public IReadOnlyList<Sabab> InSurah(int surah) => _bySurah.TryGetValue(surah, out var l) ? l : [];
    public int SurahCount => _bySurah.Count;
}

// ============================================================ غزوات النبي ﷺ (ghazawat.json)

public sealed record GhazwaSection([property: JsonPropertyName("h")] string Heading, [property: JsonPropertyName("p")] string Text);
public sealed record GhazwaAyat([property: JsonPropertyName("s")] int Surah, [property: JsonPropertyName("a")] int From,
    [property: JsonPropertyName("b")] int? To, string? Note);
public sealed record GhazwaHadith([property: JsonPropertyName("c")] string Collection, [property: JsonPropertyName("n")] int Number,
    [property: JsonPropertyName("t")] string? Title, [property: JsonPropertyName("q")] string? Contains)
{
    public string CollectionName => SahihLookup.CollectionName(Collection);
    public Hadith? Find() => SahihLookup.Find(Collection, Number, contains: Contains);
}
public sealed record GhazwaRef([property: JsonPropertyName("t")] string Title, [property: JsonPropertyName("u")] string Url);

public sealed record Ghazwa(string Id, string Name, string? Kind, int Year, string Date, string Place, double Lat, double Lng,
    string? Muslims, string? Enemy, string? Result, string? Summary, IReadOnlyList<GhazwaSection> Sections,
    IReadOnlyList<GhazwaAyat> Ayat, IReadOnlyList<GhazwaHadith> Hadith, IReadOnlyList<string> Lessons, IReadOnlyList<GhazwaRef>? Refs)
{
    /// <summary>صلح الحديبية is listed with the battles but is not one.</summary>
    public bool IsBattle => (Kind ?? "ghazwa") == "ghazwa";

    /// <summary>The recorded narration (male voice «مازن»), published with the stories' audio.</summary>
    public string AudioUrl => $"https://github.com/M-goma/mawaqeety/releases/download/stories-audio/ghazwa-{Id}-mazen.mp3";
}

public sealed record GhazawatBook(string Intro, string Note, IReadOnlyList<GhazwaRef>? Sources, IReadOnlyList<Ghazwa> Items)
{
    private static readonly Lazy<GhazawatBook> _default = new(() =>
    {
        var b = Res.Load<GhazawatBook>("ghazawat.json");
        return b with { Items = b.Items.OrderBy(g => g.Year).ToList() }; // stable: same order as the mobile list
    });
    public static GhazawatBook Default => _default.Value;
}

// ============================================================ النسب الشريف (nasab.json, from mobile/lib/data/nasab.dart by tools/build_dart_data.py)

public sealed record SourceLink(string Label, string Url);
public sealed record Ancestor(string Name, string? Note);

/// <summary>A companion's lineage from himself up to the ancestor he shares with the Prophet ﷺ (last of <see cref="Chain"/>).</summary>
public sealed record CompanionNasab(string Id, string Name, string Clan, IReadOnlyList<string> Chain, int Meet, SourceLink Source, string? Remark)
{
    public string Lineage => string.Join(" بن ", Chain);
}

public sealed record NasabBook(string Intro, string Agreed, string Mother, string BukhariRef, SourceLink Fath, SourceLink Zad,
    SourceLink MotherSource, IReadOnlyList<Ancestor> Chain, IReadOnlyList<CompanionNasab> Companions, IReadOnlyList<SourceLink> Sources)
{
    private static readonly Lazy<NasabBook> _default = new(() => Res.Load<NasabBook>("nasab.json"));
    public static NasabBook Default => _default.Value;
}

// ============================================================ كيف أسلم الصحابة (companions_islam.json, from companions_islam.dart)

public sealed record IslamHadith(string Text, int Number);
public sealed record CompanionIslam(string Id, string Name, string By, string Story, IReadOnlyList<SourceLink> Sources,
    string? Age, bool AgeDisputed, IslamHadith? Hadith);
public sealed record CompanionsIslamBook(string Intro, string Footnote, IReadOnlyList<CompanionIslam> List)
{
    private static readonly Lazy<CompanionsIslamBook> _default = new(() => Res.Load<CompanionsIslamBook>("companions_islam.json"));
    public static CompanionsIslamBook Default => _default.Value;
}

// ============================================================ أطلس قصص الأنبياء (atlas.json, from atlas.dart)

public sealed record AtlasPlace(string Name, double Lat, double Lng, IReadOnlyList<string> Prophets, string Note, string Source, string Certainty)
{
    public string CertaintyLabel => Certainty switch { "text" => "ثابت بالنص", "most" => "قول أكثر المفسرين", _ => "قول بعض المؤرخين" };
    public string MapUrl => AtlasBook.MapUrl(Lat, Lng);
}

public sealed record AtlasBook(IReadOnlyList<AtlasPlace> Places)
{
    private static readonly Lazy<AtlasBook> _default = new(() => Res.Load<AtlasBook>("atlas.json"));
    public static AtlasBook Default => _default.Value;

    public static string MapUrl(double lat, double lng) =>
        FormattableString.Invariant($"https://www.openstreetmap.org/?mlat={lat}&mlon={lng}#map=7/{lat}/{lng}");
}

// ============================================================ التقويم الميلادي

public static class CalendarEvents
{
    /// <summary>Events of a day: Islamic occasions and the white days (same rules as the mobile calendar).</summary>
    public static List<string> On(DateOnly d, int hijriAdjustment = 0)
    {
        var h = HijriDate.From(d, hijriAdjustment);
        var list = new List<string>();
        foreach (var o in Occasions.All)
            if (h.Month == o.Month && h.Day >= o.Day && h.Day < o.Day + o.Days && (o.Days == 1 || h.Day == o.Day))
                list.Add(o.Name); // multi-day seasons are named on their first day only
        if (IsWhiteDay(h)) list.Add("الأيام البيض");
        if (h.Day == 1 && list.All(e => !e.Contains("رمضان") && !e.Contains("السنة")))
            list.Add("بداية " + HijriDate.MonthNameAr(h.Month));
        return list;
    }

    public static bool IsWhiteDay(HijriDate h) => h.Month != 9 && h.Day is >= 13 and <= 15;
}
