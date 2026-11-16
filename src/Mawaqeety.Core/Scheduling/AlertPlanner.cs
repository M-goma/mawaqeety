using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Scheduling;

public sealed record PlannedAlert(
    DateOnly Date,
    Prayer Prayer,
    AlertKind Kind,
    DateTimeOffset FireAt,
    DateTimeOffset PrayerTime,
    AlertMode Mode,
    string? SoundPath,
    int MinutesBefore);

public sealed record AlertEvaluation(
    IReadOnlyList<PlannedAlert> Due,
    DateTimeOffset? NextFireAt);

/// <summary>
/// Pure, side-effect-free alert planning. Given prayer times, settings and "now", decides which alerts
/// are due and when the next one is. Persistence of fired alerts (de-duplication) is done by the caller.
/// </summary>
public static class AlertPlanner
{
    /// <summary>An at-time alert is still delivered if the PC was asleep/off for up to this long after the time.</summary>
    public static readonly TimeSpan AtTimeGrace = TimeSpan.FromMinutes(15);

    public static IReadOnlyList<PlannedAlert> Build(IEnumerable<DailyPrayerTimes> days, AppSettings s)
    {
        var list = new List<PlannedAlert>();
        foreach (var day in days)
        {
            foreach (var (prayer, time) in day.Items())
            {
                var a = s.AlertFor(prayer);
                if (!a.Enabled || a.Mode == AlertMode.Off) continue;

                list.Add(new PlannedAlert(day.Date, prayer, AlertKind.AtTime, time, time, a.Mode, a.SoundPath, 0));

                if (s.PreAlertEnabled && s.PreAlertMinutes > 0 && s.PreAlertMode != AlertMode.Off)
                {
                    list.Add(new PlannedAlert(day.Date, prayer, AlertKind.PreAlert,
                        time.AddMinutes(-s.PreAlertMinutes), time, s.PreAlertMode, a.SoundPath, s.PreAlertMinutes));
                }
            }
        }
        return list.OrderBy(a => a.FireAt).ToList();
    }

    public static AlertEvaluation Evaluate(
        IReadOnlyList<PlannedAlert> alerts,
        DateTimeOffset now,
        Func<PlannedAlert, bool> alreadyHandled)
    {
        var due = new List<PlannedAlert>();
        DateTimeOffset? next = null;

        foreach (var a in alerts)
        {
            if (a.FireAt > now)
            {
                if (next is null || a.FireAt < next) next = a.FireAt;
                continue;
            }

            var late = now - a.FireAt;
            var stillRelevant = a.Kind switch
            {
                AlertKind.PreAlert => now < a.PrayerTime,       // a reminder after the prayer started is useless
                AlertKind.AtTime => late <= AtTimeGrace,
                _ => false,
            };
            if (stillRelevant && !alreadyHandled(a)) due.Add(a);
        }

        // If both a pre-alert and the at-time alert of the same prayer are due (e.g. after wake-up), keep only at-time.
        var atTime = due.Where(d => d.Kind == AlertKind.AtTime).Select(d => (d.Date, d.Prayer)).ToHashSet();
        due.RemoveAll(d => d.Kind == AlertKind.PreAlert && atTime.Contains((d.Date, d.Prayer)));

        return new AlertEvaluation(due, next);
    }
}
