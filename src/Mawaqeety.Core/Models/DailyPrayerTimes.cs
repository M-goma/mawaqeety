namespace Mawaqeety.Core.Models;

/// <summary>Prayer times of one local calendar day at one location. All instants are absolute (UTC-backed).</summary>
public sealed record DailyPrayerTimes(
    DateOnly Date,
    DateTimeOffset Fajr,
    DateTimeOffset Sunrise,
    DateTimeOffset Dhuhr,
    DateTimeOffset Asr,
    DateTimeOffset Maghrib,
    DateTimeOffset Isha,
    string Source)
{
    public DateTimeOffset this[Prayer p] => p switch
    {
        Prayer.Fajr => Fajr,
        Prayer.Sunrise => Sunrise,
        Prayer.Dhuhr => Dhuhr,
        Prayer.Asr => Asr,
        Prayer.Maghrib => Maghrib,
        Prayer.Isha => Isha,
        _ => throw new ArgumentOutOfRangeException(nameof(p)),
    };

    public IEnumerable<(Prayer Prayer, DateTimeOffset Time)> Items()
        => PrayerExtensions.All.Select(p => (p, this[p]));

    /// <summary>Returns a copy with every time converted to the given zone (same instants, local offsets).</summary>
    public DailyPrayerTimes ToZone(TimeZoneInfo zone) => this with
    {
        Fajr = TimeZoneInfo.ConvertTime(Fajr, zone),
        Sunrise = TimeZoneInfo.ConvertTime(Sunrise, zone),
        Dhuhr = TimeZoneInfo.ConvertTime(Dhuhr, zone),
        Asr = TimeZoneInfo.ConvertTime(Asr, zone),
        Maghrib = TimeZoneInfo.ConvertTime(Maghrib, zone),
        Isha = TimeZoneInfo.ConvertTime(Isha, zone),
    };

    public DailyPrayerTimes AddMinutes(IReadOnlyDictionary<Prayer, int> adj) => this with
    {
        Fajr = Fajr.AddMinutes(adj.GetValueOrDefault(Prayer.Fajr)),
        Sunrise = Sunrise.AddMinutes(adj.GetValueOrDefault(Prayer.Sunrise)),
        Dhuhr = Dhuhr.AddMinutes(adj.GetValueOrDefault(Prayer.Dhuhr)),
        Asr = Asr.AddMinutes(adj.GetValueOrDefault(Prayer.Asr)),
        Maghrib = Maghrib.AddMinutes(adj.GetValueOrDefault(Prayer.Maghrib)),
        Isha = Isha.AddMinutes(adj.GetValueOrDefault(Prayer.Isha)),
    };
}
