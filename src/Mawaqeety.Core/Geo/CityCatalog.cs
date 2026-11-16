using System.Globalization;
using System.Text;
using System.Text.Json;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Geo;

/// <summary>Offline catalog of cities (all Egyptian governorates, Arab cities and major world cities).</summary>
public sealed class CityCatalog
{
    private sealed record Row(string En, string Ar, string Cc, double Lat, double Lng, string Tz, double Elev = 0);
    private sealed record Country(string En, string Ar);
    private sealed record Root(Dictionary<string, Country> Countries, List<Row> Cities);

    public IReadOnlyList<GeoLocation> Cities { get; }
    private readonly Dictionary<string, Country> _countries;

    private static readonly Lazy<CityCatalog> _default = new(Load);
    public static CityCatalog Default => _default.Value;

    private CityCatalog(Root root)
    {
        _countries = root.Countries;
        Cities = root.Cities.Select(r =>
        {
            var c = _countries.GetValueOrDefault(r.Cc) ?? new Country(r.Cc, r.Cc);
            return new GeoLocation
            {
                NameEn = r.En, NameAr = r.Ar, CountryCode = r.Cc, CountryEn = c.En, CountryAr = c.Ar,
                Latitude = r.Lat, Longitude = r.Lng, TimeZoneId = r.Tz, Elevation = r.Elev,
            };
        }).ToList();
    }

    private static CityCatalog Load()
    {
        using var s = typeof(CityCatalog).Assembly.GetManifestResourceStream("Mawaqeety.Core.Resources.cities.json")
            ?? throw new InvalidOperationException("cities.json resource missing");
        var root = JsonSerializer.Deserialize<Root>(s, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        return new CityCatalog(root);
    }

    public (string En, string Ar)? CountryName(string code) =>
        _countries.TryGetValue(code.ToUpperInvariant(), out var c) ? (c.En, c.Ar) : null;

    /// <summary>Accent/diacritic-insensitive search in Arabic and English (city or country).</summary>
    public IReadOnlyList<GeoLocation> Search(string query, int limit = 30)
    {
        var q = Normalize(query);
        if (q.Length == 0) return [];
        return Cities
            .Select(c => (c, score: Score(c, q)))
            .Where(x => x.score > 0)
            .OrderByDescending(x => x.score)
            .ThenBy(x => x.c.NameEn)
            .Take(limit)
            .Select(x => x.c)
            .ToList();
    }

    private static int Score(GeoLocation c, string q)
    {
        var en = Normalize(c.NameEn);
        var ar = Normalize(c.NameAr);
        if (en == q || ar == q) return 100;
        if (en.StartsWith(q, StringComparison.Ordinal) || ar.StartsWith(q, StringComparison.Ordinal)) return 80;
        if (en.Contains(q, StringComparison.Ordinal) || ar.Contains(q, StringComparison.Ordinal)) return 60;
        var country = Normalize(c.CountryEn) + " " + Normalize(c.CountryAr);
        if (country.Contains(q, StringComparison.Ordinal)) return 30;
        return 0;
    }

    /// <summary>Nearest catalog city to coordinates, with distance in km.</summary>
    public (GeoLocation City, double DistanceKm) Nearest(double lat, double lng) =>
        Cities.Select(c => (c, d: DistanceKm(lat, lng, c.Latitude, c.Longitude))).MinBy(x => x.d);

    /// <summary>If every catalog city of the country shares one time zone, returns it.</summary>
    public string? SingleTimeZoneOf(string countryCode)
    {
        var zones = Cities.Where(c => c.CountryCode.Equals(countryCode, StringComparison.OrdinalIgnoreCase))
            .Select(c => c.TimeZoneId).Distinct().ToList();
        return zones.Count == 1 ? zones[0] : null;
    }

    public static double DistanceKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6371;
        double Rad(double d) => d * Math.PI / 180;
        var dLat = Rad(lat2 - lat1);
        var dLon = Rad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * r * Math.Asin(Math.Sqrt(a));
    }

    /// <summary>Lower-case, strips Latin accents and Arabic diacritics, unifies alef/yaa/taa-marbuta forms.</summary>
    public static string Normalize(string s)
    {
        if (string.IsNullOrWhiteSpace(s)) return "";
        var d = s.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(d.Length);
        foreach (var ch in d)
        {
            var cat = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (cat == UnicodeCategory.NonSpacingMark) continue;           // Latin accents + Arabic harakat
            if (ch == 'ـ') continue;                                   // tatweel
            sb.Append(ch switch
            {
                'أ' or 'إ' or 'آ' or 'ٱ' => 'ا',
                'ى' => 'ي',
                'ة' => 'ه',
                'ؤ' => 'و',
                'ئ' => 'ي',
                '-' or '\'' or '’' => ' ',
                _ => ch,
            });
        }
        var r = sb.ToString().Normalize(NormalizationForm.FormC);
        if (r.StartsWith("ال", StringComparison.Ordinal) && r.Length > 3) r = r[2..]; // "القاهرة" ~ "قاهرة"
        if (r.StartsWith("al ", StringComparison.Ordinal)) r = r[3..];
        if (r.StartsWith("el ", StringComparison.Ordinal)) r = r[3..];
        return r;
    }
}
