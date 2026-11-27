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

/// <summary>The confirmed sunnahs (رواتب، الضحى، الوتر); the bit order is the same as the mobile app's.</summary>
public enum Sunnah { Fajr, Dhuhr, Maghrib, Isha, Duha, Witr }

public static class SunnahText
{
    public static string Label(this Sunnah s) => s switch
    {
        Sunnah.Fajr => "سنة الفجر", Sunnah.Dhuhr => "سنة الظهر", Sunnah.Maghrib => "سنة المغرب",
        Sunnah.Isha => "سنة العشاء", Sunnah.Duha => "الضحى", _ => "الوتر",
    };

    public static string Detail(this Sunnah s) => s switch
    {
        Sunnah.Fajr => "ركعتان قبل الفجر", Sunnah.Dhuhr => "٤ قبل الظهر و٢ بعده", Sunnah.Maghrib => "ركعتان بعد المغرب",
        Sunnah.Isha => "ركعتان بعد العشاء", Sunnah.Duha => "ركعتان أو أكثر", _ => "ركعة أو أكثر",
    };
}

/// <summary>One day of worship: the five prayers, morning/evening adhkar, tasbeeh, fasts, night prayer, sunan and Mushaf pages.</summary>
public sealed class DayLog
{
    public static readonly Prayer[] Tracked = [Prayer.Fajr, Prayer.Dhuhr, Prayer.Asr, Prayer.Maghrib, Prayer.Isha];

    public Dictionary<Prayer, PrayerLog> Prayers { get; } = [];
    public bool Morning { get; set; }
    public bool Evening { get; set; }
    public int Tasbeeh { get; set; }
    /// <summary>A voluntary or Ramadan fast ("f").</summary>
    public bool Fast { get; set; }
    /// <summary>Taraweeh rak'ahs, 0 = none ("tr").</summary>
    public int Taraweeh { get; set; }
    /// <summary>Night prayer ("q").</summary>
    public bool Tahajjud { get; set; }
    /// <summary>Sunnah prayers done, one bit per <see cref="Sunnah"/> ("sn").</summary>
    public int Sunan { get; set; }
    /// <summary>Distinct Mushaf pages read ("qp").</summary>
    public int Pages { get; set; }

    public bool Did(Sunnah s) => (Sunan & (1 << (int)s)) != 0;
    public int SunanDone => Enum.GetValues<Sunnah>().Count(Did);

    public PrayerLog Of(Prayer p) => Prayers.TryGetValue(p, out var l) ? l : PrayerLog.None;
    public int PrayersDone => Tracked.Count(p => Of(p) != PrayerLog.None);
    public bool AllFiveOnTime => Tracked.All(p => Of(p) is not (PrayerLog.None or PrayerLog.Qada));
    public bool IsEmpty => Prayers.Count == 0 && !Morning && !Evening && Tasbeeh == 0
        && !Fast && Taraweeh == 0 && !Tahajjud && Sunan == 0 && Pages == 0;

    private static int Int(JsonNode? n)
    {
        if (n is not JsonValue v || v.GetValueKind() != JsonValueKind.Number) return 0;
        return double.TryParse(v.ToJsonString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var x) ? (int)x : 0;
    }

    internal static DayLog FromJson(JsonObject o)
    {
        var d = new DayLog
        {
            Morning = Int(o["m"]) == 1,
            Evening = Int(o["e"]) == 1,
            Tasbeeh = Int(o["t"]),
            Fast = Int(o["f"]) == 1,
            Taraweeh = Int(o["tr"]),
            Tahajjud = Int(o["q"]) == 1,
            Sunan = Int(o["sn"]),
            Pages = Int(o["qp"]),
        };
        if (o["p"] is JsonObject p)
            foreach (var (pn, pv) in p)
                if (Enum.TryParse<Prayer>(pn, true, out var prayer) && Int(pv) is int n and > 0 and <= 4)
                    d.Prayers[prayer] = (PrayerLog)n;
        return d;
    }

    internal JsonObject ToJson()
    {
        var o = new JsonObject();
        if (Prayers.Count > 0) o["p"] = new JsonObject(Prayers.Select(p => KeyValuePair.Create(p.Key.ToString().ToLowerInvariant(), (JsonNode?)(int)p.Value)));
        if (Morning) o["m"] = 1;
        if (Evening) o["e"] = 1;
        if (Tasbeeh > 0) o["t"] = Tasbeeh;
        if (Fast) o["f"] = 1;
        if (Taraweeh > 0) o["tr"] = Taraweeh;
        if (Tahajjud) o["q"] = 1;
        if (Sunan != 0) o["sn"] = Sunan;
        if (Pages > 0) o["qp"] = Pages;
        return o;
    }
}

/// <summary>
/// Prayers, adhkar and tasbeeh per day, kept on this PC only (%AppData%\Mawaqeety\tracker.json).
/// Same layout as the mobile app: { "yyyy-MM-dd": { "p": { "fajr": 1, … }, "m": 1, "e": 1, "t": 120, "f": 1, "tr": 8, "q": 1, "sn": 5, "qp": 3 } }.
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

    private void Load()
    {
        try
        {
            if (!File.Exists(_file)) return;
            if (JsonNode.Parse(File.ReadAllText(_file)) is JsonObject root) Read(root);
        }
        catch { /* a damaged file starts fresh */ }
    }

    private void Read(JsonObject root)
    {
        lock (_gate)
        {
            foreach (var (k, v) in root)
                if (DateOnly.TryParseExact(k, "yyyy-MM-dd", out var date) && v is JsonObject o)
                    _days[date] = DayLog.FromJson(o);
        }
    }

    /// <summary>All days as the mobile app stores them: { "yyyy-MM-dd": { "p": {…}, "m": 1, "f": 1, "qp": 5, … } }.</summary>
    public JsonObject ToJson()
    {
        var root = new JsonObject();
        lock (_gate)
            foreach (var (date, d) in _days.Where(x => !x.Value.IsEmpty).OrderBy(x => x.Key))
                root[Key(date)] = d.ToJson();
        return root;
    }

    /// <summary>The tracker part of a backup file (same layout as the mobile app).</summary>
    public string ExportJson() => ToJson().ToJsonString();

    /// <summary>Replaces all days with a backup's data.</summary>
    public void ImportJson(JsonObject root)
    {
        lock (_gate) _days.Clear();
        Read(root);
        Save();
    }

    private void Save()
    {
        var root = ToJson();
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

    public void SetFast(DateOnly date, bool v) { Edit(date).Fast = v; Save(); }
    public void SetTaraweeh(DateOnly date, int rakahs) { Edit(date).Taraweeh = Math.Max(0, rakahs); Save(); }
    public void SetTahajjud(DateOnly date, bool v) { Edit(date).Tahajjud = v; Save(); }
    public void SetPages(DateOnly date, int n) { Edit(date).Pages = Math.Max(0, n); Save(); }

    public void SetSunnah(DateOnly date, Sunnah s, bool v)
    {
        var d = Edit(date);
        d.Sunan = v ? d.Sunan | (1 << (int)s) : d.Sunan & ~(1 << (int)s);
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
