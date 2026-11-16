using Mawaqeety.Core.Data;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Services;

namespace Mawaqeety.Core.Scheduling;

/// <summary>Delivers an alert to the user (toast, sound...). Implemented by the Windows app.</summary>
public interface IAlertSink
{
    void Deliver(PlannedAlert alert, bool playSound, bool showNotification);
}

/// <summary>
/// Background loop that wakes up shortly before each alert, re-evaluates against the wall clock
/// (robust to sleep/hibernate, clock and DST changes) and records every delivered alert in SQLite
/// so the same alert is never shown twice, even across restarts.
/// </summary>
public sealed class AlertScheduler : IAsyncDisposable
{
    /// <summary>Upper bound between checks: makes the loop self-healing after sleep or clock changes.</summary>
    public static readonly TimeSpan MaxSleep = TimeSpan.FromSeconds(30);

    private readonly PrayerTimeService _times;
    private readonly AppDatabase _db;
    private readonly IAlertSink _sink;
    private readonly IClock _clock;
    private readonly IAppLog _log;
    private readonly Func<AppSettings> _settings;
    private readonly CancellationTokenSource _cts = new();
    private TaskCompletionSource _wake = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private Task? _loop;

    public AlertScheduler(PrayerTimeService times, AppDatabase db, IAlertSink sink, Func<AppSettings> settings, IClock? clock = null, IAppLog? log = null)
    {
        _times = times;
        _db = db;
        _sink = sink;
        _settings = settings;
        _clock = clock ?? SystemClock.Instance;
        _log = log ?? NullLog.Instance;
    }

    public DateTimeOffset? NextAlertAt { get; private set; }

    public void Start() => _loop ??= Task.Run(() => RunAsync(_cts.Token));

    /// <summary>Forces an immediate re-evaluation (settings changed, time changed, resumed from sleep).</summary>
    public void Poke() => Interlocked.Exchange(ref _wake, new(TaskCreationOptions.RunContinuationsAsynchronously)).TrySetResult();

    private async Task RunAsync(CancellationToken ct)
    {
        _log.Info("Alert scheduler started");
        while (!ct.IsCancellationRequested)
        {
            TimeSpan delay;
            try { delay = Tick(); }
            catch (Exception ex)
            {
                _log.Error("Scheduler tick failed", ex);
                delay = MaxSleep;
            }

            var wake = Volatile.Read(ref _wake).Task;
            try { await Task.WhenAny(Task.Delay(delay, ct), wake).ConfigureAwait(false); }
            catch (OperationCanceledException) { break; }
        }
    }

    /// <summary>One evaluation pass. Public for tests. Returns how long to sleep.</summary>
    public TimeSpan Tick()
    {
        var s = _settings();
        var zone = s.ResolveZone();
        var now = _clock.UtcNow;
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(now, zone).DateTime);

        var days = new[] { today.AddDays(-1), today, today.AddDays(1) }.Select(d => _times.GetDay(d, s)).ToList();
        var plan = AlertPlanner.Build(days, s);
        var eval = AlertPlanner.Evaluate(plan, now, a => _db.WasLogged(a.Date, a.Prayer, a.Kind));
        NextAlertAt = eval.NextFireAt;

        var paused = s.PausedUntil is { } until && until > now;
        foreach (var a in eval.Due)
        {
            var status = paused ? "suppressed" : "delivered";
            if (!_db.TryLogAlert(a.Date, a.Prayer, a.Kind, status, now)) continue; // already handled elsewhere
            if (paused) { _log.Info($"Alert suppressed (paused): {a.Prayer} {a.Kind}"); continue; }

            var sound = !s.MuteAllSounds && a.Mode is AlertMode.NotificationWithSound or AlertMode.SoundOnly;
            var toast = a.Mode is AlertMode.NotificationOnly or AlertMode.NotificationWithSound;
            _log.Info($"Alert: {a.Prayer} {a.Kind} at {a.FireAt:O} (sound={sound}, toast={toast})");
            try { _sink.Deliver(a, sound, toast); }
            catch (Exception ex) { _log.Error("Alert delivery failed", ex); }
        }

        if (eval.NextFireAt is not { } next) return MaxSleep;
        var wait = next - _clock.UtcNow;
        if (wait < TimeSpan.FromMilliseconds(200)) wait = TimeSpan.FromMilliseconds(200);
        return wait < MaxSleep ? wait : MaxSleep;
    }

    public async ValueTask DisposeAsync()
    {
        await _cts.CancelAsync().ConfigureAwait(false);
        if (_loop is not null)
        {
            try { await _loop.ConfigureAwait(false); } catch (OperationCanceledException) { }
        }
        _cts.Dispose();
    }
}
