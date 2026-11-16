using System.Globalization;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Calculation;

public sealed record CalculationOptions(
    CalculationMethod Method,
    AsrMadhab Madhab = AsrMadhab.Shafii,
    HighLatitudeRule HighLatitude = HighLatitudeRule.AngleBased,
    /// <summary>Apply elevation to sunrise/sunset. Official tables usually do not, so it is off by default.</summary>
    bool UseElevation = false)
{
    public static CalculationOptions For(MethodId id, AsrMadhab madhab = AsrMadhab.Shafii) =>
        new(CalculationMethod.Get(id), madhab);
}

/// <summary>
/// Offline astronomical prayer-time engine. Uses the standard solar-position equations
/// (as in the U.S. Naval Observatory approximation, also used by PrayTimes.org) with an
/// iterative refinement, then converts results to absolute instants in the location's time zone.
/// Accuracy is typically within ±1 minute of official tables using the same convention.
/// </summary>
public static class PrayerCalculator
{
    private const int Iterations = 3;

    /// <summary>Computes the times for a local calendar date at the given location.</summary>
    public static DailyPrayerTimes Calculate(DateOnly date, GeoLocation loc, CalculationOptions opt, TimeZoneInfo? zone = null)
    {
        zone ??= TimeZoneResolver.Resolve(loc.TimeZoneId);
        var lat = loc.Latitude;
        var lng = loc.Longitude;

        // Julian day of local midnight-ish, shifted by longitude so "day portion" t ~ local solar time / 24.
        var jDate = JulianDate(date.Year, date.Month, date.Day) - lng / (15.0 * 24.0);

        // Initial guesses in local solar hours.
        double fajr = 5, sunrise = 6, dhuhr = 12, asr = 13, sunset = 18, maghrib = 18, isha = 18;
        var riseSetAngle = 0.833 + (opt.UseElevation ? 0.0347 * Math.Sqrt(Math.Max(0, loc.Elevation)) : 0);
        var m = opt.Method;
        var asrFactor = (int)opt.Madhab;

        for (var i = 0; i < Iterations; i++)
        {
            fajr = SunAngleTime(jDate, m.FajrAngle, P(fajr, 5), lat, ccw: true);
            sunrise = SunAngleTime(jDate, riseSetAngle, P(sunrise, 6), lat, ccw: true);
            dhuhr = MidDay(jDate, P(dhuhr, 12));
            asr = AsrTime(jDate, asrFactor, P(asr, 13), lat);
            sunset = SunAngleTime(jDate, riseSetAngle, P(sunset, 18), lat, ccw: false);
            maghrib = m.MaghribAngle is { } ma ? SunAngleTime(jDate, ma, P(maghrib, 18), lat, ccw: false) : sunset;
            isha = m.IshaAngle is { } ia ? SunAngleTime(jDate, ia, P(isha, 18), lat, ccw: false) : isha;
        }

        // Minute-based rules.
        if (m.MaghribAngle is null) maghrib = sunset + m.MaghribMinutes / 60.0;
        if (m.IshaMinutes is { } im)
        {
            var minutes = im;
            if (m.IshaMinutesInRamadan is { } ram && IsRamadan(date)) minutes = ram;
            isha = maghrib + minutes / 60.0;
        }

        // High-latitude adjustment (also catches NaN when the sun never reaches the angle).
        if (opt.HighLatitude != HighLatitudeRule.None && !double.IsNaN(sunrise) && !double.IsNaN(sunset))
        {
            var night = TimeDiff(sunset, sunrise);
            fajr = AdjustHighLat(fajr, sunrise, m.FajrAngle, night, opt.HighLatitude, ccw: true);
            if (m.IshaAngle is { } ia)
                isha = AdjustHighLat(isha, sunset, ia, night, opt.HighLatitude, ccw: false);
            if (m.MaghribAngle is { } ma)
                maghrib = AdjustHighLat(maghrib, sunset, ma, night, opt.HighLatitude, ccw: false);
        }

        // Local solar hours -> UTC hours.
        var shift = -lng / 15.0;
        DateTimeOffset ToInstant(double h)
        {
            if (double.IsNaN(h)) throw new InvalidOperationException("Prayer time is undefined for this location/date.");
            var utcMidnight = new DateTimeOffset(date.Year, date.Month, date.Day, 0, 0, 0, TimeSpan.Zero);
            // Round to the nearest minute.
            var minutes = Math.Round((h + shift) * 60.0, MidpointRounding.AwayFromZero);
            return TimeZoneInfo.ConvertTime(utcMidnight.AddMinutes(minutes), zone);
        }

        return new DailyPrayerTimes(date,
            ToInstant(fajr), ToInstant(sunrise), ToInstant(dhuhr), ToInstant(asr), ToInstant(maghrib), ToInstant(isha),
            Source: "local");
    }

    public static bool IsRamadan(DateOnly date)
    {
        try
        {
            var cal = new UmAlQuraCalendar();
            return cal.GetMonth(date.ToDateTime(TimeOnly.MinValue)) == 9;
        }
        catch (ArgumentOutOfRangeException) { return false; }
    }

    // ---------------- astronomy ----------------

    internal static double JulianDate(int year, int month, int day)
    {
        if (month <= 2) { year -= 1; month += 12; }
        var a = Math.Floor(year / 100.0);
        var b = 2 - a + Math.Floor(a / 4.0);
        return Math.Floor(365.25 * (year + 4716)) + Math.Floor(30.6001 * (month + 1)) + day + b - 1524.5;
    }

    /// <summary>Sun declination (deg) and equation of time (hours) for a Julian day.</summary>
    internal static (double Declination, double EquationOfTime) SunPosition(double jd)
    {
        var d = jd - 2451545.0;
        var g = FixAngle(357.529 + 0.98560028 * d);
        var q = FixAngle(280.459 + 0.98564736 * d);
        var l = FixAngle(q + 1.915 * DSin(g) + 0.020 * DSin(2 * g));
        var e = 23.439 - 0.00000036 * d;
        var ra = DArcTan2(DCos(e) * DSin(l), DCos(l)) / 15.0;
        var eqt = q / 15.0 - FixHour(ra);
        var decl = DArcSin(DSin(e) * DSin(l));
        return (decl, eqt);
    }

    private static double MidDay(double jDate, double t)
    {
        var eqt = SunPosition(jDate + t).EquationOfTime;
        return FixHour(12 - eqt);
    }

    private static double SunAngleTime(double jDate, double angle, double t, double lat, bool ccw)
    {
        var decl = SunPosition(jDate + t).Declination;
        var noon = MidDay(jDate, t);
        var cosH = (-DSin(angle) - DSin(decl) * DSin(lat)) / (DCos(decl) * DCos(lat));
        if (cosH < -1 || cosH > 1) return double.NaN;
        var h = DArcCos(cosH) / 15.0;
        return noon + (ccw ? -h : h);
    }

    private static double AsrTime(double jDate, int factor, double t, double lat)
    {
        var decl = SunPosition(jDate + t).Declination;
        var angle = -DArcCot(factor + DTan(Math.Abs(lat - decl)));
        return SunAngleTime(jDate, angle, t, lat, ccw: false);
    }

    private static double AdjustHighLat(double time, double baseTime, double angle, double night, HighLatitudeRule rule, bool ccw)
    {
        var portion = rule switch
        {
            HighLatitudeRule.AngleBased => angle / 60.0,
            HighLatitudeRule.OneSeventh => 1.0 / 7.0,
            HighLatitudeRule.MiddleOfNight => 0.5,
            _ => 1.0,
        } * night;
        var diff = ccw ? TimeDiff(time, baseTime) : TimeDiff(baseTime, time);
        if (double.IsNaN(time) || diff > portion)
            return baseTime + (ccw ? -portion : portion);
        return time;
    }

    /// <summary>Day portion for the next iteration; falls back to the default guess when undefined.</summary>
    private static double P(double hours, double fallback) => (double.IsNaN(hours) ? fallback : hours) / 24.0;

    private static double TimeDiff(double t1, double t2) => FixHour(t2 - t1);

    // ---------------- math helpers (degrees) ----------------
    private static double Rad(double d) => d * Math.PI / 180.0;
    private static double Deg(double r) => r * 180.0 / Math.PI;
    private static double DSin(double d) => Math.Sin(Rad(d));
    private static double DCos(double d) => Math.Cos(Rad(d));
    private static double DTan(double d) => Math.Tan(Rad(d));
    private static double DArcSin(double x) => Deg(Math.Asin(x));
    private static double DArcCos(double x) => Deg(Math.Acos(x));
    private static double DArcTan2(double y, double x) => Deg(Math.Atan2(y, x));
    private static double DArcCot(double x) => Deg(Math.Atan(1.0 / x));
    private static double FixAngle(double a) => Fix(a, 360);
    private static double FixHour(double a) => Fix(a, 24);
    private static double Fix(double a, double b) { a -= b * Math.Floor(a / b); return a < 0 ? a + b : a; }
}
