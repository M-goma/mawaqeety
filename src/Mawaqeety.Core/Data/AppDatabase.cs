using System.Globalization;
using Microsoft.Data.Sqlite;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Data;

/// <summary>
/// Local SQLite store: settings, fired-notification log (de-duplication across restarts),
/// cached online prayer times (offline use) and recent locations.
/// </summary>
public sealed class AppDatabase
{
    private readonly string _connectionString;
    private readonly object _gate = new();

    public string FilePath { get; }

    public AppDatabase(string filePath)
    {
        FilePath = filePath;
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(filePath))!);
        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = filePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Private,
        }.ToString();
        Migrate();
    }

    private SqliteConnection Open()
    {
        var c = new SqliteConnection(_connectionString);
        c.Open();
        return c;
    }

    private void Migrate()
    {
        lock (_gate)
        {
            using var c = Open();
            Exec(c, "PRAGMA journal_mode=WAL;");
            Exec(c, """
                CREATE TABLE IF NOT EXISTS settings (
                    key   TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS notification_log (
                    local_date TEXT NOT NULL,
                    prayer     TEXT NOT NULL,
                    kind       TEXT NOT NULL,
                    status     TEXT NOT NULL,
                    logged_at  TEXT NOT NULL,
                    PRIMARY KEY (local_date, prayer, kind)
                );
                CREATE TABLE IF NOT EXISTS prayer_cache (
                    location_key TEXT NOT NULL,
                    calc_key     TEXT NOT NULL,
                    local_date   TEXT NOT NULL,
                    fajr TEXT NOT NULL, sunrise TEXT NOT NULL, dhuhr TEXT NOT NULL,
                    asr  TEXT NOT NULL, maghrib TEXT NOT NULL, isha TEXT NOT NULL,
                    source     TEXT NOT NULL,
                    fetched_at TEXT NOT NULL,
                    PRIMARY KEY (location_key, calc_key, local_date)
                );
                CREATE TABLE IF NOT EXISTS recent_locations (
                    location_key TEXT PRIMARY KEY,
                    json         TEXT NOT NULL,
                    used_at      TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS schema_info (version INTEGER NOT NULL);
                INSERT INTO schema_info(version) SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM schema_info);
                """);
        }
    }

    private static void Exec(SqliteConnection c, string sql, params (string, object?)[] args)
    {
        using var cmd = c.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (n, v) in args) cmd.Parameters.AddWithValue(n, v ?? DBNull.Value);
        cmd.ExecuteNonQuery();
    }

    // ---------- settings ----------
    public AppSettings LoadSettings()
    {
        lock (_gate)
        {
            using var c = Open();
            using var cmd = c.CreateCommand();
            cmd.CommandText = "SELECT value FROM settings WHERE key = 'app'";
            var json = cmd.ExecuteScalar() as string;
            if (json is null) return new AppSettings();
            try { return SettingsSerializer.Deserialize(json); }
            catch (Exception) { return new AppSettings(); } // corrupted -> defaults (logged by caller)
        }
    }

    public void SaveSettings(AppSettings s)
    {
        lock (_gate)
        {
            using var c = Open();
            Exec(c, "INSERT INTO settings(key, value) VALUES('app', $v) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                ("$v", SettingsSerializer.Serialize(s)));
        }
    }

    // ---------- notification log ----------
    /// <summary>Atomically records an alert. Returns false if it was already recorded (never fire twice).</summary>
    public bool TryLogAlert(DateOnly localDate, Prayer prayer, AlertKind kind, string status, DateTimeOffset now)
    {
        lock (_gate)
        {
            using var c = Open();
            using var cmd = c.CreateCommand();
            cmd.CommandText = """
                INSERT OR IGNORE INTO notification_log(local_date, prayer, kind, status, logged_at)
                VALUES($d, $p, $k, $s, $t)
                """;
            cmd.Parameters.AddWithValue("$d", localDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
            cmd.Parameters.AddWithValue("$p", prayer.ToString());
            cmd.Parameters.AddWithValue("$k", kind.ToString());
            cmd.Parameters.AddWithValue("$s", status);
            cmd.Parameters.AddWithValue("$t", now.ToString("O", CultureInfo.InvariantCulture));
            return cmd.ExecuteNonQuery() == 1;
        }
    }

    public bool WasLogged(DateOnly localDate, Prayer prayer, AlertKind kind)
    {
        lock (_gate)
        {
            using var c = Open();
            using var cmd = c.CreateCommand();
            cmd.CommandText = "SELECT 1 FROM notification_log WHERE local_date=$d AND prayer=$p AND kind=$k";
            cmd.Parameters.AddWithValue("$d", localDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
            cmd.Parameters.AddWithValue("$p", prayer.ToString());
            cmd.Parameters.AddWithValue("$k", kind.ToString());
            return cmd.ExecuteScalar() is not null;
        }
    }

    public void PruneLog(DateOnly olderThan)
    {
        lock (_gate)
        {
            using var c = Open();
            Exec(c, "DELETE FROM notification_log WHERE local_date < $d",
                ("$d", olderThan.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)));
        }
    }

    // ---------- prayer cache ----------
    public void UpsertCache(string locationKey, string calcKey, IEnumerable<DailyPrayerTimes> days, DateTimeOffset now)
    {
        lock (_gate)
        {
            using var c = Open();
            using var tx = c.BeginTransaction();
            foreach (var d in days)
            {
                using var cmd = c.CreateCommand();
                cmd.Transaction = tx;
                cmd.CommandText = """
                    INSERT INTO prayer_cache(location_key, calc_key, local_date, fajr, sunrise, dhuhr, asr, maghrib, isha, source, fetched_at)
                    VALUES($l, $c, $d, $f, $sr, $dh, $a, $m, $i, $src, $t)
                    ON CONFLICT(location_key, calc_key, local_date) DO UPDATE SET
                      fajr=excluded.fajr, sunrise=excluded.sunrise, dhuhr=excluded.dhuhr, asr=excluded.asr,
                      maghrib=excluded.maghrib, isha=excluded.isha, source=excluded.source, fetched_at=excluded.fetched_at
                    """;
                cmd.Parameters.AddWithValue("$l", locationKey);
                cmd.Parameters.AddWithValue("$c", calcKey);
                cmd.Parameters.AddWithValue("$d", d.Date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
                cmd.Parameters.AddWithValue("$f", Iso(d.Fajr));
                cmd.Parameters.AddWithValue("$sr", Iso(d.Sunrise));
                cmd.Parameters.AddWithValue("$dh", Iso(d.Dhuhr));
                cmd.Parameters.AddWithValue("$a", Iso(d.Asr));
                cmd.Parameters.AddWithValue("$m", Iso(d.Maghrib));
                cmd.Parameters.AddWithValue("$i", Iso(d.Isha));
                cmd.Parameters.AddWithValue("$src", d.Source);
                cmd.Parameters.AddWithValue("$t", Iso(now));
                cmd.ExecuteNonQuery();
            }
            tx.Commit();
        }
    }

    public DailyPrayerTimes? GetCached(string locationKey, string calcKey, DateOnly date)
    {
        lock (_gate)
        {
            using var c = Open();
            using var cmd = c.CreateCommand();
            cmd.CommandText = """
                SELECT fajr, sunrise, dhuhr, asr, maghrib, isha, source FROM prayer_cache
                WHERE location_key=$l AND calc_key=$c AND local_date=$d
                """;
            cmd.Parameters.AddWithValue("$l", locationKey);
            cmd.Parameters.AddWithValue("$c", calcKey);
            cmd.Parameters.AddWithValue("$d", date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
            using var r = cmd.ExecuteReader();
            if (!r.Read()) return null;
            return new DailyPrayerTimes(date, P(r.GetString(0)), P(r.GetString(1)), P(r.GetString(2)),
                P(r.GetString(3)), P(r.GetString(4)), P(r.GetString(5)), r.GetString(6));
        }
    }

    public void PruneCache(DateOnly olderThan)
    {
        lock (_gate)
        {
            using var c = Open();
            Exec(c, "DELETE FROM prayer_cache WHERE local_date < $d",
                ("$d", olderThan.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)));
        }
    }

    // ---------- recent locations ----------
    public void TouchRecentLocation(GeoLocation loc, DateTimeOffset now)
    {
        lock (_gate)
        {
            using var c = Open();
            Exec(c, """
                INSERT INTO recent_locations(location_key, json, used_at) VALUES($k, $j, $t)
                ON CONFLICT(location_key) DO UPDATE SET json=excluded.json, used_at=excluded.used_at
                """,
                ("$k", loc.CacheKey), ("$j", System.Text.Json.JsonSerializer.Serialize(loc)), ("$t", Iso(now)));
            Exec(c, "DELETE FROM recent_locations WHERE location_key NOT IN (SELECT location_key FROM recent_locations ORDER BY used_at DESC LIMIT 10)");
        }
    }

    public IReadOnlyList<GeoLocation> RecentLocations()
    {
        lock (_gate)
        {
            using var c = Open();
            using var cmd = c.CreateCommand();
            cmd.CommandText = "SELECT json FROM recent_locations ORDER BY used_at DESC";
            using var r = cmd.ExecuteReader();
            var list = new List<GeoLocation>();
            while (r.Read())
            {
                var l = System.Text.Json.JsonSerializer.Deserialize<GeoLocation>(r.GetString(0));
                if (l is not null) list.Add(l);
            }
            return list;
        }
    }

    private static string Iso(DateTimeOffset t) => t.ToString("O", CultureInfo.InvariantCulture);
    private static DateTimeOffset P(string s) => DateTimeOffset.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
}
