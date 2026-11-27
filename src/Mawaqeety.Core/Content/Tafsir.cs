using System.IO.Compression;
using System.Text.Json;

namespace Mawaqeety.Core.Content;

/// <summary>
/// التفسير الميسر (مجمع الملك فهد), one text per ayah (tafsir_muyassar.json.gz, built by tools/build_tafsir.py;
/// the same file as the mobile app).
/// </summary>
public sealed class Tafsir
{
    private static readonly Lazy<Tafsir> _default = new(Load);
    public static Tafsir Default => _default.Value;

    public string Name { get; }
    public string Source { get; }
    private readonly string[][] _t;
    private readonly Lazy<string[][]> _norm;

    private Tafsir(string name, string source, string[][] t)
    {
        Name = name;
        Source = source;
        _t = t;
        _norm = new(() => _t.Select(s => s.Select(QuranRepository.Normalize).ToArray()).ToArray());
    }

    private static Tafsir Load()
    {
        using var s = Res.Open("tafsir_muyassar.json.gz");
        using var gz = new GZipStream(s, CompressionMode.Decompress);
        using var doc = JsonDocument.Parse(gz);
        var r = doc.RootElement;
        var t = r.GetProperty("t").EnumerateArray().Select(x => x.EnumerateArray().Select(a => a.GetString() ?? "").ToArray()).ToArray();
        return new Tafsir(r.GetProperty("name").GetString() ?? "", r.GetProperty("src").GetString() ?? "", t);
    }

    public string Of(int surah, int ayah) => _t[surah - 1][ayah - 1];

    /// <summary>The tafsir with diacritics removed and letter forms unified (for search).</summary>
    internal string Normalized(int surah, int ayah) => _norm.Value[surah - 1][ayah - 1];
}
