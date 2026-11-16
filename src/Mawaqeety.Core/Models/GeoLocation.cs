using System.Globalization;

namespace Mawaqeety.Core.Models;

/// <summary>A place the user selected. TimeZoneId may be IANA ("Africa/Cairo") or Windows ("Egypt Standard Time").</summary>
public sealed record GeoLocation
{
    public string NameAr { get; init; } = "";
    public string NameEn { get; init; } = "";
    public string CountryAr { get; init; } = "";
    public string CountryEn { get; init; } = "";
    public string CountryCode { get; init; } = "";
    public double Latitude { get; init; }
    public double Longitude { get; init; }
    public double Elevation { get; init; }
    public string TimeZoneId { get; init; } = "";

    /// <summary>Stable key used for caching (coordinates rounded to ~100 m).</summary>
    public string CacheKey => string.Create(CultureInfo.InvariantCulture,
        $"{Math.Round(Latitude, 3)},{Math.Round(Longitude, 3)},{TimeZoneId}");

    public string DisplayName(bool arabic)
    {
        var city = arabic && NameAr.Length > 0 ? NameAr : (NameEn.Length > 0 ? NameEn : NameAr);
        var country = arabic && CountryAr.Length > 0 ? CountryAr : (CountryEn.Length > 0 ? CountryEn : CountryAr);
        return country.Length > 0 ? $"{city}، {country}".Replace("،", arabic ? "،" : ",") : city;
    }

    public static GeoLocation Cairo { get; } = new()
    {
        NameAr = "القاهرة", NameEn = "Cairo", CountryAr = "مصر", CountryEn = "Egypt", CountryCode = "EG",
        Latitude = 30.0444, Longitude = 31.2357, Elevation = 23, TimeZoneId = "Africa/Cairo",
    };
}
