using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Scheduling;

public sealed record PrayerStatus(
    Prayer? Current,
    DateTimeOffset? CurrentStart,
    Prayer Next,
    DateTimeOffset NextTime,
    TimeSpan Remaining,
    /// <summary>0..1 progress from the previous time to the next one.</summary>
    double Progress);

public static class PrayerStatusCalculator
{
    /// <summary>
    /// Finds the current period and the next time. Needs yesterday (for after-midnight before Fajr),
    /// today and tomorrow (for after Isha).
    /// </summary>
    public static PrayerStatus Compute(DateTimeOffset now, DailyPrayerTimes yesterday, DailyPrayerTimes today, DailyPrayerTimes tomorrow)
    {
        var timeline = yesterday.Items().Concat(today.Items()).Concat(tomorrow.Items())
            .OrderBy(x => x.Time).ToList();

        var nextIndex = timeline.FindIndex(x => x.Time > now);
        if (nextIndex <= 0) nextIndex = Math.Max(0, nextIndex); // defensive; with 3 days this is always > 0
        var next = timeline[nextIndex];
        var prev = nextIndex > 0 ? timeline[nextIndex - 1] : next;

        // After sunrise there is no "current prayer" until Dhuhr.
        Prayer? current = prev.Prayer == Prayer.Sunrise ? null : prev.Prayer;
        var span = (next.Time - prev.Time).TotalSeconds;
        var progress = span <= 0 ? 0 : Math.Clamp((now - prev.Time).TotalSeconds / span, 0, 1);

        return new PrayerStatus(current, current is null ? null : prev.Time, next.Prayer, next.Time, next.Time - now, progress);
    }
}
