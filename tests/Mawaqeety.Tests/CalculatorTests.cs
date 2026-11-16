using System.Globalization;
using System.Text.Json;
using Mawaqeety.Core;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Tests;

public class CalculatorTests
{
    private static readonly TimeSpan Tolerance = TimeSpan.FromSeconds(90);

    public sealed record Ref(string City, double Lat, double Lng, string Date, double FajrAngle, double? IshaAngle,
        string Sunrise, string Sunset, string Noon, string? Fajr, string? Isha);

    public static TheoryData<string> Cases()
    {
        var data = new TheoryData<string>();
        foreach (var r in Load()) data.Add($"{r.City}|{r.Date}");
        return data;
    }

    private static List<Ref> Load() =>
        JsonSerializer.Deserialize<List<Ref>>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "reference_times.json")))!;

    /// <summary>Compares the engine against astral (independent NOAA implementation).</summary>
    [Theory]
    [MemberData(nameof(Cases))]
    public void Matches_independent_astronomy_reference(string id)
    {
        var r = Load().Single(x => $"{x.City}|{x.Date}" == id);
        var loc = new GeoLocation { Latitude = r.Lat, Longitude = r.Lng, TimeZoneId = "UTC" };
        var method = CalculationMethod.Custom(r.FajrAngle, r.IshaAngle ?? 17);
        var opt = new CalculationOptions(method, AsrMadhab.Shafii, HighLatitudeRule.None);
        var date = DateOnly.ParseExact(r.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture);

        // Fajr/Isha may be undefined (high-latitude summer) -> engine throws without a high-latitude rule.
        if (r.Fajr is null || r.Isha is null && r.IshaAngle is not null)
        {
            var adjusted = PrayerCalculator.Calculate(date, loc, opt with { HighLatitude = HighLatitudeRule.AngleBased }, TimeZoneInfo.Utc);
            Assert.True(adjusted.Fajr < adjusted.Sunrise && adjusted.Isha > adjusted.Maghrib);
            return;
        }

        var t = PrayerCalculator.Calculate(date, loc, opt, TimeZoneInfo.Utc);
        AssertClose(r.Sunrise, t.Sunrise, "sunrise");
        AssertClose(r.Sunset, t.Maghrib, "sunset/maghrib");
        AssertClose(r.Noon, t.Dhuhr, "noon/dhuhr");
        AssertClose(r.Fajr, t.Fajr, "fajr");
        if (r.Isha is not null) AssertClose(r.Isha, t.Isha, "isha");
    }

    private static void AssertClose(string expectedIso, DateTimeOffset actual, string what)
    {
        var expected = DateTimeOffset.Parse(expectedIso, CultureInfo.InvariantCulture);
        var diff = (expected - actual).Duration();
        Assert.True(diff <= Tolerance, $"{what}: expected {expected:HH:mm:ss}Z got {actual.UtcDateTime:HH:mm:ss}Z (diff {diff.TotalSeconds:F0}s)");
    }

    [Fact]
    public void Cairo_egyptian_method_is_in_expected_order_and_range()
    {
        var t = PrayerCalculator.Calculate(new DateOnly(2026, 1, 1), GeoLocation.Cairo, CalculationOptions.For(MethodId.Egyptian));
        Assert.True(t.Fajr < t.Sunrise && t.Sunrise < t.Dhuhr && t.Dhuhr < t.Asr && t.Asr < t.Maghrib && t.Maghrib < t.Isha);
        // Cairo 1 Jan, Egyptian Survey method (hand-checked spherical trigonometry; Asr: H = acos((sin 23.25° + sin30·sin23°)/(cos30·cos23°)) ≈ 2h49m after noon)
        AssertLocal(t.Fajr, 5, 18); AssertLocal(t.Sunrise, 6, 51); AssertLocal(t.Dhuhr, 11, 58);
        AssertLocal(t.Asr, 14, 47); AssertLocal(t.Maghrib, 17, 6); AssertLocal(t.Isha, 18, 27);
    }

    private static void AssertLocal(DateTimeOffset t, int h, int m)
    {
        var diff = Math.Abs((t.Hour * 60 + t.Minute) - (h * 60 + m));
        Assert.True(diff <= 2, $"expected ~{h:00}:{m:00} got {t:HH:mm}");
    }

    [Fact]
    public void Asr_shadow_ratio_is_correct_for_both_madhabs()
    {
        var date = new DateOnly(2026, 11, 16);
        var shafii = PrayerCalculator.Calculate(date, GeoLocation.Cairo, CalculationOptions.For(MethodId.Egyptian, AsrMadhab.Shafii));
        var hanafi = PrayerCalculator.Calculate(date, GeoLocation.Cairo, CalculationOptions.For(MethodId.Egyptian, AsrMadhab.Hanafi));
        Assert.InRange((hanafi.Asr - shafii.Asr).TotalMinutes, 25, 75);

        // Independent check: at Asr, shadow = factor + shadow at noon, i.e. cot(altitude) = factor + tan(|lat - decl|)
        foreach (var (time, factor) in new[] { (shafii.Asr, 1), (hanafi.Asr, 2) })
        {
            var (alt, decl) = SolarAltitude(time.UtcDateTime, GeoLocation.Cairo.Latitude, GeoLocation.Cairo.Longitude);
            var expectedCot = factor + Math.Tan(Math.Abs(GeoLocation.Cairo.Latitude - decl) * Math.PI / 180);
            var actualCot = 1 / Math.Tan(alt * Math.PI / 180);
            Assert.InRange(actualCot, expectedCot - 0.03, expectedCot + 0.03);
        }
    }

    /// <summary>NOAA solar position (independent of the engine's formula set).</summary>
    private static (double Altitude, double Declination) SolarAltitude(DateTime utc, double lat, double lng)
    {
        var jd = utc.ToOADate() + 2415018.5;
        var jc = (jd - 2451545) / 36525;
        double Rad(double d) => d * Math.PI / 180;
        double Deg(double r) => r * 180 / Math.PI;
        var l0 = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360;
        var m = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);
        var e = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);
        var c = Math.Sin(Rad(m)) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) + Math.Sin(Rad(2 * m)) * (0.019993 - 0.000101 * jc) + Math.Sin(Rad(3 * m)) * 0.000289;
        var trueLong = l0 + c;
        var appLong = trueLong - 0.00569 - 0.00478 * Math.Sin(Rad(125.04 - 1934.136 * jc));
        var obliq = 23 + (26 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60) / 60 + 0.00256 * Math.Cos(Rad(125.04 - 1934.136 * jc));
        var decl = Deg(Math.Asin(Math.Sin(Rad(obliq)) * Math.Sin(Rad(appLong))));
        var y = Math.Tan(Rad(obliq / 2)) * Math.Tan(Rad(obliq / 2));
        var eqTime = 4 * Deg(y * Math.Sin(2 * Rad(l0)) - 2 * e * Math.Sin(Rad(m)) + 4 * e * y * Math.Sin(Rad(m)) * Math.Cos(2 * Rad(l0)) - 0.5 * y * y * Math.Sin(4 * Rad(l0)) - 1.25 * e * e * Math.Sin(2 * Rad(m)));
        var minutes = utc.TimeOfDay.TotalMinutes;
        var trueSolar = (minutes + eqTime + 4 * lng) % 1440;
        var ha = trueSolar / 4 < 0 ? trueSolar / 4 + 180 : trueSolar / 4 - 180;
        var zenith = Deg(Math.Acos(Math.Sin(Rad(lat)) * Math.Sin(Rad(decl)) + Math.Cos(Rad(lat)) * Math.Cos(Rad(decl)) * Math.Cos(Rad(ha))));
        return (90 - zenith, decl);
    }

    [Fact]
    public void UmmAlQura_isha_is_90_minutes_after_maghrib_and_120_in_ramadan()
    {
        var makkah = new GeoLocation { Latitude = 21.4225, Longitude = 39.8262, TimeZoneId = "Asia/Riyadh" };
        var normal = PrayerCalculator.Calculate(new DateOnly(2026, 11, 16), makkah, CalculationOptions.For(MethodId.UmmAlQura));
        Assert.Equal(90, (normal.Isha - normal.Maghrib).TotalMinutes);

        var ramadanDay = Enumerable.Range(0, 400).Select(i => new DateOnly(2026, 1, 1).AddDays(i)).First(PrayerCalculator.IsRamadan);
        var ramadan = PrayerCalculator.Calculate(ramadanDay, makkah, CalculationOptions.For(MethodId.UmmAlQura));
        Assert.Equal(120, (ramadan.Isha - ramadan.Maghrib).TotalMinutes);
    }

    [Fact]
    public void Daylight_saving_shifts_local_clock_not_the_sun()
    {
        // Cairo observes DST (last Friday of April -> last Thursday of October since 2023).
        var before = PrayerCalculator.Calculate(new DateOnly(2026, 4, 23), GeoLocation.Cairo, CalculationOptions.For(MethodId.Egyptian));
        var after = PrayerCalculator.Calculate(new DateOnly(2026, 5, 7), GeoLocation.Cairo, CalculationOptions.For(MethodId.Egyptian));
        Assert.Equal(TimeSpan.FromHours(2), before.Dhuhr.Offset);
        Assert.Equal(TimeSpan.FromHours(3), after.Dhuhr.Offset);
        // In UTC, noon barely moves in two weeks; in local clock time it jumps by ~1 hour.
        Assert.True(Math.Abs((after.Dhuhr.UtcDateTime.TimeOfDay - before.Dhuhr.UtcDateTime.TimeOfDay).TotalMinutes) < 3);
        Assert.InRange((after.Dhuhr.TimeOfDay - before.Dhuhr.TimeOfDay).TotalMinutes, 57, 63);
    }

    [Fact]
    public void London_has_no_dst_bugs_on_transition_day()
    {
        var london = new GeoLocation { Latitude = 51.5072, Longitude = -0.1276, TimeZoneId = "Europe/London" };
        var t = PrayerCalculator.Calculate(new DateOnly(2026, 3, 29), london, CalculationOptions.For(MethodId.MuslimWorldLeague));
        Assert.Equal(TimeSpan.FromHours(1), t.Dhuhr.Offset); // BST starts 01:00 UTC on 29 Mar 2026
        Assert.InRange(t.Dhuhr.Hour, 13, 13);
    }

    [Fact]
    public void High_latitude_summer_produces_valid_ordered_times()
    {
        var oslo = new GeoLocation { Latitude = 59.9139, Longitude = 10.7522, TimeZoneId = "Europe/Oslo" };
        foreach (var rule in new[] { HighLatitudeRule.AngleBased, HighLatitudeRule.OneSeventh, HighLatitudeRule.MiddleOfNight })
        {
            var t = PrayerCalculator.Calculate(new DateOnly(2026, 6, 21), oslo, new CalculationOptions(CalculationMethod.Get(MethodId.MuslimWorldLeague), AsrMadhab.Shafii, rule));
            Assert.True(t.Fajr < t.Sunrise && t.Sunrise < t.Dhuhr && t.Dhuhr < t.Asr && t.Asr < t.Maghrib && t.Maghrib < t.Isha, rule.ToString());
        }
    }

    [Theory]
    [InlineData("Asia/Tokyo")]
    [InlineData("America/Los_Angeles")]
    [InlineData("Pacific/Auckland")]
    public void Times_fall_on_the_requested_local_date_for_far_east_and_west(string tz)
    {
        var city = Mawaqeety.Core.Geo.CityCatalog.Default.Cities.First(c => c.TimeZoneId == tz);
        var date = new DateOnly(2026, 11, 16);
        var t = PrayerCalculator.Calculate(date, city, CalculationOptions.For(MethodId.MuslimWorldLeague));
        foreach (var (_, time) in t.Items().Where(x => x.Prayer != Prayer.Isha))
            Assert.Equal(date, DateOnly.FromDateTime(time.DateTime));
    }

    [Fact]
    public void Every_method_and_every_catalog_city_produces_ordered_times()
    {
        var date = new DateOnly(2026, 12, 21);
        foreach (var m in CalculationMethod.All)
        foreach (var c in Mawaqeety.Core.Geo.CityCatalog.Default.Cities)
        {
            var t = PrayerCalculator.Calculate(date, c, new CalculationOptions(m));
            Assert.True(t.Fajr < t.Sunrise && t.Sunrise < t.Dhuhr && t.Dhuhr < t.Asr && t.Asr < t.Maghrib && t.Maghrib <= t.Isha,
                $"{m.Id} {c.NameEn}");
        }
    }

    [Fact]
    public void Manual_offset_with_dst_adds_an_hour()
    {
        var s = new AppSettings { AutoTimeZone = false, ManualUtcOffsetMinutes = 120, ManualDstEnabled = true };
        Assert.Equal(TimeSpan.FromHours(3), s.ResolveZone().BaseUtcOffset);
    }

    [Fact]
    public void Hijri_date_supports_adjustment()
    {
        var d = new DateOnly(2026, 11, 16);
        var h = HijriDate.From(d);
        var h1 = HijriDate.From(d, 1);
        Assert.InRange(h.Year, 1447, 1449);
        Assert.NotEqual(h, h1);
        Assert.Contains("هـ", h.ToDisplay(true));
    }
}
