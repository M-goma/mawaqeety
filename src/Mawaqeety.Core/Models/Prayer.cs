namespace Mawaqeety.Core.Models;

/// <summary>The six daily times shown by the app. Sunrise is not a prayer but marks the end of Fajr.</summary>
public enum Prayer
{
    Fajr = 0,
    Sunrise = 1,
    Dhuhr = 2,
    Asr = 3,
    Maghrib = 4,
    Isha = 5,
}

public static class PrayerExtensions
{
    public static readonly Prayer[] All =
        [Prayer.Fajr, Prayer.Sunrise, Prayer.Dhuhr, Prayer.Asr, Prayer.Maghrib, Prayer.Isha];

    /// <summary>The five obligatory prayers (no Sunrise).</summary>
    public static readonly Prayer[] Obligatory =
        [Prayer.Fajr, Prayer.Dhuhr, Prayer.Asr, Prayer.Maghrib, Prayer.Isha];

    public static bool IsObligatory(this Prayer p) => p != Prayer.Sunrise;
}
