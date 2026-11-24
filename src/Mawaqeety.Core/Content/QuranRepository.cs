using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Mawaqeety.Core.Content;

public sealed record Surah(int Number, string Name, string NameEn, bool Meccan, IReadOnlyList<string> Verses);

public sealed record AyahHit(Surah Surah, int Ayah)
{
    public string Text => Surah.Verses[Ayah - 1];
}

public sealed record AyahRef(int Surah, int From, int To, string Note);
public sealed record StorySection(string Heading, string Body);

public sealed record Prophet(
    string Id, int Order, string NameAr, string NameEn, string Title, string Summary,
    IReadOnlyList<StorySection> Sections, IReadOnlyList<AyahRef> Ayat, IReadOnlyList<string> Lessons);

/// <summary>
/// The Uthmani Qur'an text (6236 ayahs, from quranenc.com via quran-json, CC BY-SA 4.0) and the
/// stories of the 25 prophets, both embedded in the assembly so they work offline.
/// The same data files are used by the mobile app.
/// </summary>
public sealed class QuranRepository
{
    private static readonly Lazy<QuranRepository> _default = new(() => new QuranRepository());
    public static QuranRepository Default => _default.Value;

    public IReadOnlyList<Surah> Surahs { get; }
    public IReadOnlyList<Prophet> Prophets { get; }
    private readonly string[][] _normalized;

    private QuranRepository()
    {
        var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        using (var s = Open("quran.json"))
        {
            var raw = JsonSerializer.Deserialize<List<SurahDto>>(s, opts)!;
            Surahs = raw.Select(r => new Surah(r.N, r.Name, r.En, r.Type == "m", r.V)).ToList();
        }
        _normalized = Surahs.Select(s => s.Verses.Select(SearchKey).ToArray()).ToArray();

        using (var s = Open("prophets.json"))
        {
            var raw = JsonSerializer.Deserialize<List<ProphetDto>>(s, opts)!;
            Prophets = raw.OrderBy(p => p.Order).Select(p => new Prophet(
                p.Id, p.Order, p.NameAr, p.NameEn ?? "", p.Title ?? "", p.Summary ?? "",
                (p.Sections ?? []).Select(x => new StorySection(x.Heading ?? "", x.Body ?? "")).ToList(),
                (p.Ayat ?? []).Select(a => new AyahRef(a.Surah, a.From, a.To, a.Note ?? "")).ToList(),
                p.Lessons ?? [])).ToList();
        }
    }

    private static Stream Open(string name) =>
        typeof(QuranRepository).Assembly.GetManifestResourceStream("Mawaqeety.Core.Resources." + name)
        ?? throw new InvalidOperationException(name + " resource missing");

    public Surah this[int number] => Surahs[number - 1];

    /// <summary>Diacritic-insensitive search over all ayahs.</summary>
    public IReadOnlyList<AyahHit> Search(string query, int limit = 300)
    {
        var q = SearchKey(query);
        if (q.Length < 2) return [];
        var hits = new List<AyahHit>();
        for (var s = 0; s < _normalized.Length && hits.Count < limit; s++)
            for (var a = 0; a < _normalized[s].Length && hits.Count < limit; a++)
                if (_normalized[s][a].Contains(q, StringComparison.Ordinal))
                    hits.Add(new AyahHit(Surahs[s], a + 1));
        return hits;
    }

    /// <summary>Removes harakat and Qur'anic marks and unifies alef/yaa/taa-marbuta forms.</summary>
    public static string Normalize(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (var ch in s)
        {
            if (ch is >= 'ؐ' and <= 'ؚ' or >= 'ً' and <= 'ٟ' or 'ٰ' or >= 'ۖ' and <= 'ۭ' or 'ـ')
                continue;
            sb.Append(ch switch
            {
                'أ' or 'إ' or 'آ' or 'ٱ' => 'ا',
                'ى' => 'ي',
                'ة' => 'ه',
                'ؤ' => 'و',
                'ئ' => 'ي',
                _ => char.ToLowerInvariant(ch),
            });
        }
        return sb.ToString().Trim();
    }

    /// <summary>
    /// Search key: normalized text without any alef, because the Uthmani script often omits alefs
    /// that modern spelling writes (ٱلۡعَٰلَمِينَ vs العالمين). Applied to both the query and the text.
    /// </summary>
    public static string SearchKey(string s) => Normalize(s).Replace("ا", "");

    public static string ArabicDigits(int n) =>
        string.Concat(n.ToString().Select(c => (char)('٠' + (c - '0'))));

    private sealed record SurahDto(int N, string Name, string En, string Type, List<string> V);
    private sealed record SectionDto(string? Heading, string? Body);
    private sealed record AyahDto(int Surah, int From, int To, string? Note);
    private sealed record ProphetDto(string Id, int Order, string NameAr, string? NameEn, string? Title, string? Summary,
        List<SectionDto>? Sections, List<AyahDto>? Ayat, List<string>? Lessons);
}
