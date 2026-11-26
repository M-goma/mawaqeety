using System.Text.Json;
using System.Text.Json.Nodes;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core.Tracking;

/// <summary>How a prayer was prayed.</summary>
public enum PrayerLog { None, Mosque, Jamaah, Alone, Qada }

public static class PrayerLogText
{
    public static string Label(this PrayerLog l) => l switch
    {
        PrayerLog.Mosque => "جماعة في المسجد",
        PrayerLog.Jamaah => "جماعة",
        PrayerLog.Alone => "منفردًا",
        PrayerLog.Qada => "قضاء",
        _ => "لم تُسجَّل",
    };

    public static string LongLabel(this PrayerLog l) => l switch
    {
        PrayerLog.Mosque => "جماعة في المسجد",
        PrayerLog.Jamaah => "جماعة (في البيت أو العمل)",
        PrayerLog.Alone => "منفردًا في وقتها",
        PrayerLog.Qada => "قضاء (بعد خروج الوقت)",
        _ => "",
    };

    public static string Emoji(this PrayerLog l) => l switch
    {
        PrayerLog.Mosque => "🕌", PrayerLog.Jamaah => "👥", PrayerLog.Alone => "🧍", PrayerLog.Qada => "⏳", _ => "",
    };
}

/// <summary>One day of worship: the five prayers, morning/evening adhkar and the tasbeeh count.</summary>
public sealed class DayLog
{
    public static readonly Prayer[] Tracked = [Prayer.Fajr, Prayer.Dhuhr, Prayer.Asr, Prayer.Maghrib, Prayer.Isha];

    public Dictionary<Prayer, PrayerLog> Prayers { get; } = [];
    public bool Morning { get; set; }
    public bool Evening { get; set; }
    public int Tasbeeh { get; set; }

    public PrayerLog Of(Prayer p) => Prayers.TryGetValue(p, out var l) ? l : PrayerLog.None;
    public int PrayersDone => Tracked.Count(p => Of(p) != PrayerLog.None);
    public bool AllFiveOnTime => Tracked.All(p => Of(p) is not (PrayerLog.None or PrayerLog.Qada));
    public bool IsEmpty => Prayers.Count == 0 && !Morning && !Evening && Tasbeeh == 0;
}

/// <summary>
/// Prayers, adhkar and tasbeeh per day, kept on this PC only (%AppData%\Mawaqeety\tracker.json).
/// Same layout as the mobile app: { "yyyy-MM-dd": { "p": { "fajr": 1, … }, "m": 1, "e": 1, "t": 120 } }.
/// </summary>
public sealed class Tracker
{
    private readonly string _file;
    private readonly Dictionary<DateOnly, DayLog> _days = [];
    private readonly object _gate = new();

    public event Action? Changed;
    /// <summary>Daily tasbeeh goal (0 = none), used for the "wird" item of the day.</summary>
    public Func<int> WirdGoal { get; set; } = () => 100;

    public Tracker(string file)
    {
        _file = file;
        Load();
    }

    private static string Key(DateOnly d) => d.ToString("yyyy-MM-dd");
    private static string Name(Prayer p) => p.ToString().ToLowerInvariant();

    private void Load()
    {
        try
        {
            if (!File.Exists(_file)) return;
            var root = JsonNode.Parse(File.ReadAllText(_file))?.AsObject();
            if (root is null) return;
            foreach (var (k, v) in root)
            {
                if (!DateOnly.TryParse(k, out var date) || v is not JsonObject o) continue;
                var d = new DayLog
                {
                    Morning = o["m"]?.GetValue<int>() == 1,
                    Evening = o["e"]?.GetValue<int>() == 1,
                    Tasbeeh = o["t"]?.GetValue<int>() ?? 0,
                };
                if (o["p"] is JsonObject p)
                    foreach (var (pn, pv) in p)
                        if (Enum.TryParse<Prayer>(pn, true, out var prayer) && pv?.GetValue<int>() is int n and > 0 and <= 4)
                            d.Prayers[prayer] = (PrayerLog)n;
                _days[date] = d;
            }
        }
        catch { /* a damaged file starts fresh */ }
    }

    private void Save()
    {
        var root = new JsonObject();
        lock (_gate)
        {
            foreach (var (date, d) in _days.Where(x => !x.Value.IsEmpty).OrderBy(x => x.Key))
            {
                var o = new JsonObject();
                if (d.Prayers.Count > 0) o["p"] = new JsonObject(d.Prayers.Select(p => KeyValuePair.Create(Name(p.Key), (JsonNode?)(int)p.Value)));
                if (d.Morning) o["m"] = 1;
                if (d.Evening) o["e"] = 1;
                if (d.Tasbeeh > 0) o["t"] = d.Tasbeeh;
                root[Key(date)] = o;
            }
        }
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_file)!);
            File.WriteAllText(_file + ".tmp", root.ToJsonString());
            File.Move(_file + ".tmp", _file, overwrite: true);
        }
        catch { /* best effort */ }
        Changed?.Invoke();
    }

    public DayLog Day(DateOnly date) { lock (_gate) return _days.TryGetValue(date, out var d) ? d : new DayLog(); }
    private DayLog Edit(DateOnly date) { lock (_gate) { if (!_days.TryGetValue(date, out var d)) _days[date] = d = new DayLog(); return d; } }

    public void SetPrayer(DateOnly date, Prayer p, PrayerLog log)
    {
        var d = Edit(date);
        if (log == PrayerLog.None) d.Prayers.Remove(p); else d.Prayers[p] = log;
        Save();
    }

    public void SetAdhkar(DateOnly date, bool morning, bool done = true)
    {
        var d = Edit(date);
        if (morning) d.Morning = done; else d.Evening = done;
        Save();
    }

    public void AddTasbeeh(DateOnly date, int n = 1)
    {
        Edit(date).Tasbeeh += n;
        Save();
    }

    /// <summary>0..1: the five prayers, morning and evening adhkar, and the daily wird.</summary>
    public double Completion(DateOnly date)
    {
        var d = Day(date);
        var goal = WirdGoal();
        var items = 7 + (goal > 0 ? 1 : 0);
        var done = d.PrayersDone + (d.Morning ? 1 : 0) + (d.Evening ? 1 : 0) + (goal > 0 && d.Tasbeeh >= goal ? 1 : 0);
        return done / (double)items;
    }

    /// <summary>Consecutive days (ending today, or yesterday when today is not done yet) that satisfy the test.</summary>
    public int Streak(DateOnly today, Func<DayLog, bool> test)
    {
        var date = test(Day(today)) ? today : today.AddDays(-1);
        var n = 0;
        while (n < 3650 && test(Day(date))) { n++; date = date.AddDays(-1); }
        return n;
    }

    public int PrayersStreak(DateOnly today) => Streak(today, d => d.AllFiveOnTime);
    public int FajrMosqueStreak(DateOnly today) => Streak(today, d => d.Of(Prayer.Fajr) == PrayerLog.Mosque);
    public int MorningStreak(DateOnly today) => Streak(today, d => d.Morning);

    public Dictionary<PrayerLog, int> Distribution(DateOnly from, DateOnly to)
    {
        var m = Enum.GetValues<PrayerLog>().Skip(1).ToDictionary(l => l, _ => 0);
        for (var d = from; d <= to; d = d.AddDays(1))
            foreach (var p in DayLog.Tracked)
                if (Day(d).Of(p) is var l and not PrayerLog.None) m[l]++;
        return m;
    }

    public int TasbeehBetween(DateOnly from, DateOnly to)
    {
        lock (_gate) return _days.Where(x => x.Key >= from && x.Key <= to).Sum(x => x.Value.Tasbeeh);
    }
}
