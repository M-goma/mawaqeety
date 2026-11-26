using System.Text.Json;

namespace Mawaqeety.Core.Content;

internal static class Res
{
    public static readonly JsonSerializerOptions Opts = new() { PropertyNameCaseInsensitive = true };

    public static Stream Open(string name) =>
        typeof(Res).Assembly.GetManifestResourceStream("Mawaqeety.Core.Resources." + name)
        ?? throw new InvalidOperationException(name + " resource missing");

    public static T Load<T>(string name)
    {
        using var s = Open(name);
        return JsonSerializer.Deserialize<T>(s, Opts)!;
    }
}

/// <summary>A colour style of the interface (the same ten styles as the mobile app). Colours are "#RRGGBB".</summary>
public sealed record Palette(string Id, string Name, string Bg, string Surface, string Surface2, string Primary,
    string Accent, string AccentLight, string HeroText, IReadOnlyList<string> Hero)
{
    private static readonly Lazy<IReadOnlyList<Palette>> _all = new(() => Res.Load<List<Palette>>("palettes.json"));
    public static IReadOnlyList<Palette> All => _all.Value;
    public static Palette Find(string? id) => All.FirstOrDefault(p => p.Id == id) ?? All[0];
}

/// <summary>A morning/evening remembrance. <see cref="Quran"/> holds (surah, from, to) passages shown in the Uthmani script.</summary>
public sealed record Dhikr(string? Morning, string? Evening, int Count, string Source, string Virtue, bool Basmala, IReadOnlyList<int[]> Quran)
{
    private static readonly Lazy<IReadOnlyList<Dhikr>> _all = new(() => Res.Load<List<Dhikr>>("adhkar.json"));
    public static IReadOnlyList<Dhikr> All => _all.Value;

    public string? TextFor(bool morning) => morning ? Morning : Evening;
    public bool AvailableAt(bool morning) => Quran.Count > 0 || TextFor(morning) is not null;
}

/// <summary>Great-circle direction and distance to the Kaaba.</summary>
public static class Qibla
{
    public const double KaabaLat = 21.422487, KaabaLng = 39.826206;

    /// <summary>Bearing from true north, clockwise, in degrees [0, 360).</summary>
    public static double Bearing(double lat, double lng)
    {
        double p1 = Rad(lat), p2 = Rad(KaabaLat), dl = Rad(KaabaLng - lng);
        var y = Math.Sin(dl) * Math.Cos(p2);
        var x = Math.Cos(p1) * Math.Sin(p2) - Math.Sin(p1) * Math.Cos(p2) * Math.Cos(dl);
        return (Deg(Math.Atan2(y, x)) + 360) % 360;
    }

    public static double DistanceKm(double lat, double lng)
    {
        double p1 = Rad(lat), p2 = Rad(KaabaLat), dp = p2 - p1, dl = Rad(KaabaLng - lng);
        var a = Math.Pow(Math.Sin(dp / 2), 2) + Math.Cos(p1) * Math.Cos(p2) * Math.Pow(Math.Sin(dl / 2), 2);
        return 6371.0 * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    /// <summary>Arabic name of the direction (8 points).</summary>
    public static string DirectionName(double bearing) =>
        new[] { "الشمال", "الشمال الشرقي", "الشرق", "الجنوب الشرقي", "الجنوب", "الجنوب الغربي", "الغرب", "الشمال الغربي" }
            [(int)Math.Round(((bearing % 360) + 360) % 360 / 45.0) % 8];

    private static double Rad(double d) => d * Math.PI / 180;
    private static double Deg(double r) => r * 180 / Math.PI;
}

/// <summary>Where one ayah sits on a printed Mushaf page, as rectangles in image pixels (left, top, right, bottom).</summary>
public sealed record AyahBox(int Surah, int Ayah, IReadOnlyList<(double L, double T, double R, double B)> Rects)
{
    public bool Contains(double x, double y) => Rects.Any(r => x >= r.L - 4 && x <= r.R + 4 && y >= r.T - 4 && y <= r.B + 4);
}

/// <summary>
/// Page layout of the Madinah Mushaf (604 pages, King Fahd Complex print, Hafs): where each page, juz and hizb
/// quarter starts, and where each ayah sits on its page (detected from the ayah-end markers of the page images).
/// </summary>
public sealed class MushafIndex
{
    public const int PageCount = 604;
    private static readonly Lazy<MushafIndex> _default = new(() => new MushafIndex());
    public static MushafIndex Default => _default.Value;

    public string BaseUrl { get; }
    public double ImageWidth { get; private set; } = 1440;
    public double ImageHeight { get; private set; } = 2330;
    private readonly int[] _pages, _juz, _quarters;
    private readonly Lazy<List<AyahBox>[]> _ayahs;

    private sealed record Dto(string Base, List<int[]> Pages, List<int[]> Juz, List<int[]> Quarters);
    private sealed record AyahsDto(double W, double H, List<List<JsonElement>> Pages);

    private MushafIndex()
    {
        var d = Res.Load<Dto>("mushaf.json");
        BaseUrl = d.Base;
        static int Key(int[] e) => e[0] * 1000 + e[1];
        _pages = d.Pages.Select(Key).ToArray();
        _juz = d.Juz.Select(Key).ToArray();
        _quarters = d.Quarters.Select(Key).ToArray();
        _ayahs = new(LoadAyahs);
    }

    private List<AyahBox>[] LoadAyahs()
    {
        var d = Res.Load<AyahsDto>("mushaf_ayahs.json");
        ImageWidth = d.W;
        ImageHeight = d.H;
        return d.Pages.Select(page => page.Select(a =>
        {
            var c = a.EnumerateArray().ToList();
            var n = c[2].EnumerateArray().Select(x => x.GetDouble()).ToArray();
            var rects = new List<(double, double, double, double)>();
            for (var i = 0; i + 3 < n.Length; i += 4) rects.Add((n[i], n[i + 1], n[i + 2], n[i + 3]));
            return new AyahBox(c[0].GetInt32(), c[1].GetInt32(), rects);
        }).ToList()).ToArray();
    }

    public string Url(int page) => $"{BaseUrl}{page:000}.png";

    private static int Floor(int[] starts, int k)
    {
        int lo = 0, hi = starts.Length - 1;
        while (lo < hi)
        {
            var mid = (lo + hi + 1) >> 1;
            if (starts[mid] <= k) lo = mid; else hi = mid - 1;
        }
        return lo;
    }

    /// <summary>The page (1..604) that holds an ayah.</summary>
    public int PageOf(int surah, int ayah) => Floor(_pages, surah * 1000 + Math.Max(1, ayah)) + 1;
    public (int Surah, int Ayah) StartOf(int page) => (_pages[page - 1] / 1000, _pages[page - 1] % 1000);
    public int SurahOf(int page) => _pages[page - 1] / 1000;
    public int JuzOf(int page) => Floor(_juz, _pages[page - 1]) + 1;
    public int JuzStartPage(int juz) => PageOf(_juz[juz - 1] / 1000, _juz[juz - 1] % 1000);

    /// <summary>Hizb (1..60) and the quarter (0..3) the page starts in.</summary>
    public (int Hizb, int Quarter) HizbOf(int page)
    {
        var q = Floor(_quarters, _pages[page - 1]);
        return (q / 4 + 1, q % 4);
    }

    public IReadOnlyList<AyahBox> AyahsOn(int page) => _ayahs.Value[page - 1];
}

/// <summary>Recorded narrations of the prophets' stories (male voice "Nabil", female voice "Areen").</summary>
public sealed class StoryAudio
{
    private static readonly Lazy<StoryAudio> _default = new(() => new StoryAudio());
    public static StoryAudio Default => _default.Value;

    public string BaseUrl { get; }
    private readonly Dictionary<string, Dictionary<string, int>> _parts = [];
    private readonly Dictionary<string, int> _sizeMb = [];

    private StoryAudio()
    {
        using var s = Res.Open("story_audio.json");
        using var doc = JsonDocument.Parse(s);
        BaseUrl = doc.RootElement.GetProperty("base").GetString() ?? "";
        foreach (var g in new[] { "male", "female" })
            if (doc.RootElement.TryGetProperty(g, out var m))
                _parts[g] = m.EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetInt32());
        if (doc.RootElement.TryGetProperty("sizeMB", out var sz))
            foreach (var p in sz.EnumerateObject()) _sizeMb[p.Name] = p.Value.GetInt32();
    }

    private static string Key(string gender) => gender.Equals("Female", StringComparison.OrdinalIgnoreCase) ? "female" : "male";

    /// <summary>Approximate size of all stories in one voice, in MB.</summary>
    public int SizeMb(string gender) => _sizeMb.TryGetValue(Key(gender), out var v) ? v : 100;

    /// <summary>Ids of the stories recorded in that voice.</summary>
    public IReadOnlyList<string> Ids(string gender) => _parts.TryGetValue(Key(gender), out var m) ? m.Keys.ToList() : [];

    /// <summary>File names of the recording parts, or empty when this story has no recording in that voice.</summary>
    public IReadOnlyList<string> Parts(string prophetId, string gender)
    {
        var g = gender.Equals("Female", StringComparison.OrdinalIgnoreCase) ? "female" : "male";
        return _parts.TryGetValue(g, out var m) && m.TryGetValue(prophetId, out var n)
            ? Enumerable.Range(1, n).Select(i => $"{g}-{prophetId}-{i}.mp3").ToList()
            : [];
    }
}
