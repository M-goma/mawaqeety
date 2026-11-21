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
public static partial class AdhanCatalog
{
    public const string BaseUrl = "https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/";

    public const string DefaultId = "alafasy";
    public const string DefaultFajrId = "alafasy-fajr";

    // Built lazily: static initializer order across partial files is not guaranteed.
    private static Dictionary<string, AdhanVoice>? _byId;

    public static AdhanVoice? Find(string? id) =>
        id is not null && (_byId ??= All.ToDictionary(v => v.Id)).TryGetValue(id, out var v) ? v : null;

    /// <summary>Fajr list shows the Fajr-specific recordings first, then the regular ones.</summary>
    public static IEnumerable<AdhanVoice> ForFajr => All.Where(v => v.IsFajr).Concat(All.Where(v => !v.IsFajr));
    public static IEnumerable<AdhanVoice> Regular => All.Where(v => !v.IsFajr);
}
