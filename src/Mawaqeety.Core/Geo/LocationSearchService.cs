using System.Globalization;
using System.Text.Json;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Services;

namespace Mawaqeety.Core.Geo;

/// <summary>
/// City search: offline catalog first, then OpenStreetMap Nominatim for any place worldwide.
/// IP-based location as a fallback when Windows location is unavailable.
/// </summary>
public sealed class LocationSearchService(HttpClient http, AladhanClient aladhan, IAppLog log)
{
    private readonly CityCatalog _catalog = CityCatalog.Default;

    public IReadOnlyList<GeoLocation> SearchOffline(string query) => _catalog.Search(query);

    public async Task<IReadOnlyList<GeoLocation>> SearchOnlineAsync(string query, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(query)) return [];
        var url = "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&namedetails=1&limit=10" +
                  "&featureType=settlement&accept-language=en&q=" + Uri.EscapeDataString(query.Trim());
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            using var resp = await http.SendAsync(req, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return [];
            using var doc = await JsonDocument.ParseAsync(await resp.Content.ReadAsStreamAsync(ct).ConfigureAwait(false), cancellationToken: ct).ConfigureAwait(false);
            var list = new List<GeoLocation>();
            foreach (var e in doc.RootElement.EnumerateArray())
            {
                var lat = double.Parse(e.GetProperty("lat").GetString()!, CultureInfo.InvariantCulture);
                var lon = double.Parse(e.GetProperty("lon").GetString()!, CultureInfo.InvariantCulture);
                var nameEn = e.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
                var nameAr = nameEn;
                if (e.TryGetProperty("namedetails", out var nd) && nd.ValueKind == JsonValueKind.Object)
                {
                    if (nd.TryGetProperty("name:ar", out var ar)) nameAr = ar.GetString() ?? nameAr;
                    if (nd.TryGetProperty("name:en", out var en)) nameEn = en.GetString() ?? nameEn;
                }
                var cc = "";
                var countryEn = "";
                if (e.TryGetProperty("address", out var addr))
                {
                    if (addr.TryGetProperty("country_code", out var c)) cc = (c.GetString() ?? "").ToUpperInvariant();
                    if (addr.TryGetProperty("country", out var cn)) countryEn = cn.GetString() ?? "";
                }
                var names = _catalog.CountryName(cc);
                list.Add(new GeoLocation
                {
                    NameEn = nameEn, NameAr = nameAr, CountryCode = cc,
                    CountryEn = names?.En ?? countryEn, CountryAr = names?.Ar ?? countryEn,
                    Latitude = lat, Longitude = lon,
                });
            }
            return list.DistinctBy(l => (Math.Round(l.Latitude, 2), Math.Round(l.Longitude, 2))).ToList();
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex)
        {
            log.Warn("Online city search failed", ex);
            return [];
        }
    }

    /// <summary>Fills in the time zone for a location found online (catalog → Aladhan → nearest city → system).</summary>
    public async Task<GeoLocation> CompleteAsync(GeoLocation loc, CancellationToken ct)
    {
        if (!string.IsNullOrEmpty(loc.TimeZoneId)) return loc;
        var tz = string.IsNullOrEmpty(loc.CountryCode) ? null : _catalog.SingleTimeZoneOf(loc.CountryCode);
        tz ??= await aladhan.GetTimeZoneAsync(loc.Latitude, loc.Longitude, ct).ConfigureAwait(false);
        if (tz is null)
        {
            var (city, km) = _catalog.Nearest(loc.Latitude, loc.Longitude);
            tz = km < 300 ? city.TimeZoneId : TimeZoneInfo.Local.Id;
        }
        return loc with { TimeZoneId = tz };
    }

    /// <summary>Builds a location for raw coordinates (e.g. from Windows location), naming it after the nearest city.</summary>
    public async Task<GeoLocation> FromCoordinatesAsync(double lat, double lng, CancellationToken ct)
    {
        var (city, km) = _catalog.Nearest(lat, lng);
        if (km <= 30)
            return city with { Latitude = lat, Longitude = lng };
        var named = await ReverseAsync(lat, lng, ct).ConfigureAwait(false)
                    ?? new GeoLocation { NameAr = "موقعي الحالي", NameEn = "My location", Latitude = lat, Longitude = lng };
        return await CompleteAsync(named, ct).ConfigureAwait(false);
    }

    private async Task<GeoLocation?> ReverseAsync(double lat, double lng, CancellationToken ct)
    {
        var url = string.Create(CultureInfo.InvariantCulture,
            $"https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&namedetails=1&addressdetails=1&accept-language=en&lat={lat}&lon={lng}");
        try
        {
            using var doc = JsonDocument.Parse(await http.GetStringAsync(url, ct).ConfigureAwait(false));
            var root = doc.RootElement;
            var name = root.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
            var nameAr = name;
            if (root.TryGetProperty("namedetails", out var nd) && nd.ValueKind == JsonValueKind.Object && nd.TryGetProperty("name:ar", out var ar))
                nameAr = ar.GetString() ?? name;
            var cc = root.TryGetProperty("address", out var a) && a.TryGetProperty("country_code", out var c) ? (c.GetString() ?? "").ToUpperInvariant() : "";
            var cn = _catalog.CountryName(cc);
            return new GeoLocation
            {
                NameEn = name, NameAr = nameAr, CountryCode = cc, CountryEn = cn?.En ?? cc, CountryAr = cn?.Ar ?? cc,
                Latitude = lat, Longitude = lng,
            };
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { log.Warn("Reverse geocoding failed", ex); return null; }
    }

    /// <summary>Approximate location from the public IP address (city-level).</summary>
    public async Task<GeoLocation?> FromIpAsync(CancellationToken ct)
    {
        try
        {
            using var doc = JsonDocument.Parse(await http.GetStringAsync("https://ipwho.is/", ct).ConfigureAwait(false));
            var r = doc.RootElement;
            if (r.TryGetProperty("success", out var ok) && !ok.GetBoolean()) return null;
            var lat = r.GetProperty("latitude").GetDouble();
            var lng = r.GetProperty("longitude").GetDouble();
            var tz = r.TryGetProperty("timezone", out var t) && t.TryGetProperty("id", out var id) ? id.GetString() : null;
            var loc = await FromCoordinatesAsync(lat, lng, ct).ConfigureAwait(false);
            return string.IsNullOrEmpty(tz) ? loc : loc with { TimeZoneId = tz };
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { log.Warn("IP location failed", ex); return null; }
    }
}
