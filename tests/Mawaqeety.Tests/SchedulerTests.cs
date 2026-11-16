using Mawaqeety.Core.Data;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Scheduling;
using Mawaqeety.Core.Services;

namespace Mawaqeety.Tests;

public sealed class FakeClock(DateTimeOffset now) : IClock
{
    public DateTimeOffset UtcNow { get; set; } = now;
}

public sealed class RecordingSink : IAlertSink
{
    public List<(PlannedAlert Alert, bool Sound, bool Toast)> Delivered { get; } = [];
    public void Deliver(PlannedAlert alert, bool playSound, bool showNotification) => Delivered.Add((alert, playSound, showNotification));
}

public sealed class SchedulerTests : IDisposable
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"mawaqeety-test-{Guid.NewGuid():N}.db");
    private readonly AppDatabase _db;
    private readonly AppSettings _settings = new() { Location = GeoLocation.Cairo, PreAlertEnabled = true, PreAlertMinutes = 10 };
    private readonly PrayerTimeService _times;

    public SchedulerTests()
    {
        _db = new AppDatabase(_dbPath);
        _times = new PrayerTimeService(_db, null);
    }

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        foreach (var f in new[] { _dbPath, _dbPath + "-wal", _dbPath + "-shm" })
            try { File.Delete(f); } catch { }
    }

    private DailyPrayerTimes Today(DateOnly d) => _times.GetDay(d, _settings);

    private (AlertScheduler, RecordingSink, FakeClock) Create(DateTimeOffset now)
    {
        var sink = new RecordingSink();
        var clock = new FakeClock(now);
        return (new AlertScheduler(_times, _db, sink, () => _settings, clock), sink, clock);
    }

    [Fact]
    public void Fires_at_prayer_time_exactly_once_even_across_restarts()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        var (s1, sink1, clock) = Create(day.Asr.AddSeconds(1));
        s1.Tick();
        s1.Tick();
        Assert.Single(sink1.Delivered, d => d.Alert.Prayer == Prayer.Asr && d.Alert.Kind == AlertKind.AtTime);

        // Simulated app restart: new scheduler, same database.
        var (s2, sink2, _) = Create(day.Asr.AddSeconds(30));
        s2.Tick();
        Assert.DoesNotContain(sink2.Delivered, d => d.Alert.Prayer == Prayer.Asr && d.Alert.Kind == AlertKind.AtTime);
    }

    [Fact]
    public void Pre_alert_fires_before_prayer_and_next_wake_is_accurate()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        var (s, sink, clock) = Create(day.Maghrib.AddMinutes(-10).AddSeconds(-5));
        var wait = s.Tick();
        Assert.DoesNotContain(sink.Delivered, d => d.Alert.Prayer == Prayer.Maghrib);
        Assert.InRange(wait.TotalSeconds, 4, 6); // wakes up right on time

        clock.UtcNow = day.Maghrib.AddMinutes(-10);
        s.Tick();
        var pre = Assert.Single(sink.Delivered, d => d.Alert.Prayer == Prayer.Maghrib);
        Assert.Equal(AlertKind.PreAlert, pre.Alert.Kind);
    }

    [Fact]
    public void Wake_from_sleep_within_grace_delivers_once_and_skips_stale_pre_alert()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        var (s, sink, _) = Create(day.Dhuhr.AddMinutes(5)); // PC was asleep through pre-alert and the time
        s.Tick();
        var dhuhr = sink.Delivered.Where(d => d.Alert.Prayer == Prayer.Dhuhr).ToList();
        Assert.Single(dhuhr);
        Assert.Equal(AlertKind.AtTime, dhuhr[0].Alert.Kind);
    }

    [Fact]
    public void Alerts_older_than_grace_are_not_delivered()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        var (s, sink, _) = Create(day.Dhuhr.AddMinutes(40));
        s.Tick();
        Assert.Empty(sink.Delivered);
    }

    [Fact]
    public void Paused_alerts_are_suppressed_and_not_replayed_after_resume()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        _settings.PausedUntil = day.Isha.AddMinutes(5);
        var (s, sink, clock) = Create(day.Isha.AddSeconds(2));
        s.Tick();
        Assert.Empty(sink.Delivered);
        _settings.PausedUntil = null;
        clock.UtcNow = day.Isha.AddMinutes(1);
        s.Tick();
        Assert.Empty(sink.Delivered);
    }

    [Fact]
    public void Disabled_prayer_and_modes_are_respected()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        _settings.AlertFor(Prayer.Fajr).Enabled = false;
        _settings.AlertFor(Prayer.Asr).Mode = AlertMode.SoundOnly;
        _settings.PreAlertEnabled = false;

        var (s, sink, clock) = Create(day.Fajr.AddSeconds(1));
        s.Tick();
        Assert.Empty(sink.Delivered);

        clock.UtcNow = day.Asr.AddSeconds(1);
        s.Tick();
        var asr = Assert.Single(sink.Delivered);
        Assert.True(asr.Sound);
        Assert.False(asr.Toast);
    }

    [Fact]
    public void Mute_all_sounds_keeps_notification()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        _settings.MuteAllSounds = true;
        _settings.PreAlertEnabled = false;
        var (s, sink, _) = Create(day.Isha.AddSeconds(1));
        s.Tick();
        var isha = Assert.Single(sink.Delivered);
        Assert.False(isha.Sound);
        Assert.True(isha.Toast);
    }

    [Fact]
    public void Crossing_midnight_schedules_tomorrows_fajr()
    {
        var day = Today(new DateOnly(2026, 11, 16));
        var tomorrow = Today(new DateOnly(2026, 11, 17));
        _settings.PreAlertEnabled = false;
        var (s, sink, clock) = Create(day.Isha.AddHours(2));
        s.Tick();
        Assert.Equal(tomorrow.Fajr, s.NextAlertAt);
        clock.UtcNow = tomorrow.Fajr.AddSeconds(1);
        s.Tick();
        Assert.Contains(sink.Delivered, d => d.Alert.Prayer == Prayer.Fajr && d.Alert.Date == tomorrow.Date);
    }

    [Fact]
    public void Status_reports_next_prayer_and_progress()
    {
        var d = new DateOnly(2026, 11, 16);
        var y = Today(d.AddDays(-1)); var t = Today(d); var n = Today(d.AddDays(1));
        var mid = t.Dhuhr + (t.Asr - t.Dhuhr) / 2;
        var st = PrayerStatusCalculator.Compute(mid, y, t, n);
        Assert.Equal(Prayer.Dhuhr, st.Current);
        Assert.Equal(Prayer.Asr, st.Next);
        Assert.InRange(st.Progress, 0.49, 0.51);

        var afterSunrise = PrayerStatusCalculator.Compute(t.Sunrise.AddMinutes(5), y, t, n);
        Assert.Null(afterSunrise.Current);
        Assert.Equal(Prayer.Dhuhr, afterSunrise.Next);

        var beforeFajr = PrayerStatusCalculator.Compute(t.Fajr.AddHours(-1), y, t, n);
        Assert.Equal(Prayer.Isha, beforeFajr.Current);
        Assert.Equal(Prayer.Fajr, beforeFajr.Next);
    }

    [Fact]
    public void Settings_round_trip_through_sqlite()
    {
        _settings.Language = AppLanguage.English;
        _settings.AlertFor(Prayer.Maghrib).SoundPath = @"C:\adhan.mp3";
        _settings.AlertFor(Prayer.Maghrib).AdjustmentMinutes = 3;
        _db.SaveSettings(_settings);
        var loaded = _db.LoadSettings();
        Assert.Equal(AppLanguage.English, loaded.Language);
        Assert.Equal(@"C:\adhan.mp3", loaded.AlertFor(Prayer.Maghrib).SoundPath);
        Assert.Equal(3, loaded.AlertFor(Prayer.Maghrib).AdjustmentMinutes);
    }

    [Fact]
    public void Minute_adjustment_is_applied()
    {
        var d = new DateOnly(2026, 11, 16);
        var before = Today(d);
        _settings.AlertFor(Prayer.Dhuhr).AdjustmentMinutes = 4;
        _times.InvalidateMemory();
        var after = Today(d);
        Assert.Equal(4, (after.Dhuhr - before.Dhuhr).TotalMinutes);
        Assert.Equal(before.Asr, after.Asr);
    }

    [Fact]
    public void Online_cache_is_used_only_when_plausible()
    {
        var d = new DateOnly(2026, 11, 16);
        var local = Today(d);
        _settings.Source = TimeSource.OnlineWithLocalFallback;
        var shifted = local with { Fajr = local.Fajr.AddMinutes(1), Source = "aladhan" };
        _db.UpsertCache(_settings.Location.CacheKey, _settings.CalculationKey(), [shifted], DateTimeOffset.UtcNow);
        _times.InvalidateMemory();
        Assert.Equal("aladhan", Today(d).Source);

        var bogus = local with { Fajr = local.Fajr.AddHours(2), Source = "aladhan" };
        _db.UpsertCache(_settings.Location.CacheKey, _settings.CalculationKey(), [bogus], DateTimeOffset.UtcNow);
        _times.InvalidateMemory();
        Assert.Equal("local", Today(d).Source);
    }
}
