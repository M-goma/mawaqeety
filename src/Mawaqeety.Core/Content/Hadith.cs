using System.IO.Compression;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Mawaqeety.Core.Content;

/// <summary>One hadith: its book, common number, full text (with the chain) and where the companion's narration starts.</summary>
public sealed record Hadith(HadithCollection Collection, int Index, int Book, int Number, string Text, int MatnStart)
{
    public bool HasMatn => MatnStart > 0;
    public string Matn => HasMatn ? Text[MatnStart..] : Text;
}

/// <summary>صحيح البخاري / صحيح مسلم (hadith_&lt;id&gt;.json.gz, built by tools/build_hadith.py; same files as the mobile app).</summary>
public sealed class HadithCollection
{
    public static readonly string[] Ids = ["bukhari", "muslim"];
    private static readonly Dictionary<string, HadithCollection> Cache = [];

    public string Id { get; }
    public string Name { get; }
    public IReadOnlyList<(int Number, string Name)> Books { get; }
    public IReadOnlyList<Hadith> All { get; }
    private readonly Dictionary<int, int> _counts = [];
    private string[]? _plain;
    private List<Hadith>? _daily;

    private HadithCollection(string id, JsonElement root)
    {
        Id = id;
        Name = root.GetProperty("name").GetString()!;
        Books = root.GetProperty("books").EnumerateArray().Select(b => (b[0].GetInt32(), b[1].GetString()!)).ToList();
        var list = new List<Hadith>();
        var i = 0;
        foreach (var h in root.GetProperty("h").EnumerateArray())
        {
            var x = new Hadith(this, i++, h[0].GetInt32(), h[1].GetInt32(), h[2].GetString()!, h[3].GetInt32());
            list.Add(x);
            _counts[x.Book] = _counts.GetValueOrDefault(x.Book) + 1;
        }
        All = list;
    }

    public static HadithCollection Load(string id)
    {
        lock (Cache)
        {
            if (Cache.TryGetValue(id, out var c)) return c;
            using var s = Res.Open($"hadith_{id}.json.gz");
            using var gz = new GZipStream(s, CompressionMode.Decompress);
            using var doc = JsonDocument.Parse(gz);
            return Cache[id] = new HadithCollection(id, doc.RootElement);
        }
    }

    public string BookName(int n) => "كتاب " + Books.FirstOrDefault(b => b.Number == n).Name;
    public int BookCount(int n) => _counts.GetValueOrDefault(n);
    public IEnumerable<Hadith> InBook(int n) => All.Where(h => h.Book == n);

    private static readonly Regex Diacritics = new("[ً-ْٰـ]", RegexOptions.Compiled);
    public static string Plain(string s) => Diacritics.Replace(s, "")
        .Replace('أ', 'ا').Replace('إ', 'ا').Replace('آ', 'ا').Replace('ٱ', 'ا').Replace('ى', 'ي').Replace('ة', 'ه')
        .Replace('ؤ', 'و').Replace('ئ', 'ي');

    /// <summary>Hadiths containing every word of <paramref name="query"/> (diacritics and hamza forms ignored).</summary>
    public List<Hadith> Search(string query, int max = 150)
    {
        var words = Plain(query.Trim()).Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return [];
        _plain ??= All.Select(h => Plain(h.Text)).ToArray();
        var outList = new List<Hadith>();
        for (var i = 0; i < All.Count && outList.Count < max; i++)
            if (words.All(_plain[i].Contains)) outList.Add(All[i]);
        return outList;
    }

    /// <summary>A short hadith with the Prophet's ﷺ own words: five a day, a new one with each prayer
    /// (<paramref name="slot"/> 0 = Fajr … 4 = Isha; same choice as the mobile app).</summary>
    public Hadith OfDay(DateOnly day, int slot = 0)
    {
        _daily ??= All.Where(h => h.HasMatn && h.Matn.Length is >= 70 and <= 330 && h.Matn.Contains('"')).ToList();
        var n = (long)(day.ToDateTime(TimeOnly.MinValue) - DateTime.UnixEpoch).TotalDays;
        return _daily[(int)((n * 5 + slot) * 7919 % _daily.Count)];
    }

    /// <summary>Which of the day's five hadiths goes with the current prayer.</summary>
    public static int SlotFor(Models.Prayer? current) => current switch
    {
        Models.Prayer.Dhuhr => 1, Models.Prayer.Asr => 2, Models.Prayer.Maghrib => 3, Models.Prayer.Isha => 4, _ => 0,
    };

    public static readonly string[] SlotNames = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"];
}

/// <summary>The ten companions promised Paradise (companions.json).</summary>
public sealed record CompanionSituation(string Title, string Text, string Source);
public sealed record Companion(string Id, string Name, string Title, string Bio, IReadOnlyList<CompanionSituation> Situations);
public sealed record CompanionsBook(string Intro, string IntroSource, string Note, IReadOnlyList<Companion> Companions)
{
    private static readonly Lazy<CompanionsBook> _default = new(() => Res.Load<CompanionsBook>("companions.json"));
    public static CompanionsBook Default => _default.Value;
}
