using System.Collections.Concurrent;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Data;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Services;

/// <summary>
/// Single entry point for prayer times. Order of precedence:
/// 1) cached online data (if the user chose the online source and it was synced),
/// 2) the offline astronomical engine (always available).
/// Per-prayer minute adjustments and the display time zone are applied last.
/// </summary>
public sealed class PrayerTimeService
{
    /// <summary>Online data deviating more than this from the local engine is treated as invalid.</summary>
    public static readonly TimeSpan MaxOnlineDeviation = TimeSpan.FromMinutes(20);

    private readonly AppDatabase? _db;
    private readonly AladhanClient? _online;
    private readonly IAppLog _log;
    private readonly ConcurrentDictionary<string, DailyPrayerTimes> _memo = new();

    public PrayerTimeService(AppDatabase? db, AladhanClient? online, IAppLog? log = null)
    {
        _db = db;
        _online = online;
        _log = log ?? NullLog.Instance;
    }

    public void InvalidateMemory() => _memo.Clear();

    /// <summary>Final (adjusted, zoned) times for a local date.</summary>
    public DailyPrayerTimes GetDay(DateOnly date, AppSettings s)
    {
        var zone = s.ResolveZone();
        var key = $"{s.Location.CacheKey}|{s.CalculationKey()}|{s.Source}|{s.AutoTimeZone}|{s.ManualUtcOffsetMinutes}|{s.ManualDstEnabled}|{date:yyyy-MM-dd}";
        var raw = _memo.GetOrAdd(key, _ => GetRaw(date, s, zone));
        return raw.AddMinutes(s.Adjustments()).ToZone(zone);
    }

    public IReadOnlyList<DailyPrayerTimes> GetMonth(int year, int month, AppSettings s)
    {
        var days = DateTime.DaysInMonth(year, month);
        return Enumerable.Range(1, days).Select(d => GetDay(new DateOnly(year, month, d), s)).ToList();
    }

    private DailyPrayerTimes GetRaw(DateOnly date, AppSettings s, TimeZoneInfo zone)
    {
        var local = PrayerCalculator.Calculate(date, s.Location, s.ToCalculationOptions(), zone);
        if (s.Source == TimeSource.OnlineWithLocalFallback && s.AutoTimeZone && _db is not null)
        {
            try
            {
                var cached = _db.GetCached(s.Location.CacheKey, s.CalculationKey(), date);
                if (cached is not null && IsPlausible(cached, local)) return cached.ToZone(zone);
            }
            catch (Exception ex) { _log.Warn("Cache read failed", ex); }
        }
        return local;
    }

    public static bool IsPlausible(DailyPrayerTimes online, DailyPrayerTimes local) =>
        PrayerExtensions.All.All(p => (online[p] - local[p]).Duration() <= MaxOnlineDeviation);

    /// <summary>Downloads the current and next month from the online source into the local cache.</summary>
    public async Task<bool> SyncAsync(AppSettings s, DateOnly today, CancellationToken ct)
    {
        if (_online is null || _db is null || s.Source != TimeSource.OnlineWithLocalFallback || !s.AutoTimeZone)
            return false;
        var zone = s.ResolveZone();
        var ok = false;
        foreach (var m in new[] { today, today.AddMonths(1) })
        {
            var month = await _online.GetMonthAsync(m.Year, m.Month, s.Location, s, zone, ct).ConfigureAwait(false);
            if (month is null) continue;
            var valid = month.Where(d => IsPlausible(d,
                PrayerCalculator.Calculate(d.Date, s.Location, s.ToCalculationOptions(), zone))).ToList();
            if (valid.Count < month.Count)
                _log.Warn($"Discarded {month.Count - valid.Count} online days deviating > {MaxOnlineDeviation.TotalMinutes} min from local engine");
            _db.UpsertCache(s.Location.CacheKey, s.CalculationKey(), valid, DateTimeOffset.UtcNow);
            ok |= valid.Count > 0;
        }
        if (ok) { InvalidateMemory(); _log.Info("Online prayer times synced"); }
        return ok;
    }
}
