using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Services;

/// <summary>
/// Client for the public Aladhan prayer-times API (https://aladhan.com/prayer-times-api).
/// Used as an optional online source and for time-zone lookup. All failures return null (never throw).
/// </summary>
public sealed class AladhanClient(HttpClient http, IAppLog log)
{
    private const string BaseUrl = "https://api.aladhan.com/v1";

    public static int? MethodCode(MethodId id) => id switch
    {
        MethodId.Jafari => 0,
        MethodId.Karachi => 1,
        MethodId.Isna => 2,
        MethodId.MuslimWorldLeague => 3,
        MethodId.UmmAlQura => 4,
        MethodId.Egyptian => 5,
        MethodId.Tehran => 7,
        MethodId.Gulf => 8,
        MethodId.Kuwait => 9,
        MethodId.Qatar => 10,
        MethodId.Singapore => 11,
        MethodId.France => 12,
        MethodId.Turkey => 13,
        MethodId.Russia => 14,
        MethodId.Dubai => 16,
        MethodId.Tunisia => 18,
        MethodId.Algeria => 19,
        MethodId.Morocco => 21,
        MethodId.Jordan => 23,
        _ => null, // custom: not mapped -> local engine
    };

    private static int LatitudeRuleCode(HighLatitudeRule r) => r switch
    {
        HighLatitudeRule.MiddleOfNight => 1,
        HighLatitudeRule.OneSeventh => 2,
        _ => 3,
    };

    /// <summary>Downloads one Gregorian month. Returns null when offline or the response is unusable.</summary>
    public async Task<IReadOnlyList<DailyPrayerTimes>?> GetMonthAsync(
        int year, int month, GeoLocation loc, AppSettings s, TimeZoneInfo zone, CancellationToken ct)
    {
        if (MethodCode(s.Method) is not { } method) return null;
        var url = string.Create(CultureInfo.InvariantCulture,
            $"{BaseUrl}/calendar/{year}/{month}?latitude={loc.Latitude}&longitude={loc.Longitude}" +
            $"&method={method}&school={(s.Madhab == AsrMadhab.Hanafi ? 1 : 0)}" +
            $"&latitudeAdjustmentMethod={LatitudeRuleCode(s.HighLatitudeRule)}" +
            $"&timezonestring={Uri.EscapeDataString(loc.TimeZoneId)}&iso8601=true");
        try
        {
            using var resp = await http.GetAsync(url, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) { log.Warn($"Aladhan HTTP {(int)resp.StatusCode}"); return null; }
            using var doc = await JsonDocument.ParseAsync(await resp.Content.ReadAsStreamAsync(ct).ConfigureAwait(false), cancellationToken: ct).ConfigureAwait(false);
            var result = new List<DailyPrayerTimes>();
            foreach (var day in doc.RootElement.GetProperty("data").EnumerateArray())
            {
                var t = day.GetProperty("timings");
                var g = day.GetProperty("date").GetProperty("gregorian").GetProperty("date").GetString()!; // dd-MM-yyyy
                var date = DateOnly.ParseExact(g, "dd-MM-yyyy", CultureInfo.InvariantCulture);
                DateTimeOffset P(string name)
                {
                    var raw = t.GetProperty(name).GetString()!;
                    var cut = raw.IndexOf(' ');
                    if (cut > 0) raw = raw[..cut];
                    return TimeZoneInfo.ConvertTime(DateTimeOffset.Parse(raw, CultureInfo.InvariantCulture), zone);
                }
                result.Add(new DailyPrayerTimes(date, P("Fajr"), P("Sunrise"), P("Dhuhr"), P("Asr"), P("Maghrib"), P("Isha"), "aladhan"));
            }
            return result.Count > 0 ? result : null;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex)
        {
            log.Warn("Aladhan request failed (offline?)", ex);
            return null;
        }
    }

    /// <summary>Returns the IANA time zone for coordinates, or null.</summary>
    public async Task<string?> GetTimeZoneAsync(double lat, double lng, CancellationToken ct)
    {
        var url = string.Create(CultureInfo.InvariantCulture, $"{BaseUrl}/timings?latitude={lat}&longitude={lng}&method=3");
        try
        {
            using var doc = await http.GetFromJsonAsync<JsonDocument>(url, ct).ConfigureAwait(false);
            return doc?.RootElement.GetProperty("data").GetProperty("meta").GetProperty("timezone").GetString();
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex)
        {
            log.Warn("Time-zone lookup failed", ex);
            return null;
        }
    }
}
