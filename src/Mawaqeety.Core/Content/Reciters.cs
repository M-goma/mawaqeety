using System.Text.Json;

namespace Mawaqeety.Core.Content;

public sealed record Reciter(string Id, string Name);

/// <summary>
/// Qur'an reciters with verse-by-verse audio on everyayah.com (free for non-commercial use).
/// The list is verified by the "verify-audio" CI workflow.
/// </summary>
public static class Reciters
{
    public const string DefaultId = "Minshawy_Murattal_128kbps";
    public const string BaseUrl = "https://everyayah.com/data/";

    private static readonly Lazy<IReadOnlyList<Reciter>> _all = new(() =>
    {
        using var s = typeof(Reciters).Assembly.GetManifestResourceStream("Mawaqeety.Core.Resources.reciters.json")!;
        return JsonSerializer.Deserialize<List<Reciter>>(s, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
    });

    public static IReadOnlyList<Reciter> All => _all.Value;

    public static Reciter Find(string? id) => All.FirstOrDefault(r => r.Id == id) ?? All.First(r => r.Id == DefaultId);

    public static string FileName(int surah, int ayah) => $"{surah:000}{ayah:000}.mp3";

    public static string Url(string reciterId, int surah, int ayah) => $"{BaseUrl}{reciterId}/{FileName(surah, ayah)}";

    /// <summary>
    /// Playback order for a passage: the basmala (recited from Al-Fatiha 1:1) precedes ayah 1 of every
    /// surah except Al-Fatiha (where it is ayah 1) and At-Tawbah (which has none).
    /// </summary>
    public static IReadOnlyList<(int Surah, int Ayah, bool IsBasmala)> Sequence(int surah, int fromAyah, int toAyah)
    {
        var list = new List<(int, int, bool)>();
        if (fromAyah == 1 && surah != 1 && surah != 9) list.Add((1, 1, true));
        for (var a = fromAyah; a <= toAyah; a++) list.Add((surah, a, false));
        return list;
    }
}
