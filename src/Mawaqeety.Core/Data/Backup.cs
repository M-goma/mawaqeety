using System.Text.Json;
using System.Text.Json.Nodes;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.Core.Data;

/// <summary>
/// Backup file: the same shape as the mobile app's AppState.exportBackup —
/// { "app": "sabeel", "version": 1, "date": …, "settings": {…}, "tracker": {…} }.
/// The tracker part is exactly the mobile layout, so a file made on one device restores the log on the other.
/// The settings part is the desktop's own settings (marked "platform": "windows"); a phone backup's settings are
/// mostly specific to the phone, so only the shared ones (khatma plan, zakat prices, colours…) are taken from it.
/// </summary>
public static class Backup
{
    public sealed record Restored(AppSettings? Settings, JsonObject Tracker);

    public static string Export(AppSettings settings, Tracker tracker)
    {
        var root = new JsonObject
        {
            ["app"] = "sabeel",
            ["version"] = 1,
            ["platform"] = "windows",
            ["date"] = DateTimeOffset.Now.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz"),
            ["settings"] = JsonNode.Parse(SettingsSerializer.Serialize(settings)),
            ["tracker"] = tracker.ToJson(),
        };
        return root.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
    }

    /// <summary>
    /// Reads a backup. Returns null when the text is not a backup of this app. <see cref="Restored.Settings"/> is the
    /// settings to apply: the desktop settings of a desktop backup, or <paramref name="current"/> with the shared
    /// fields of a phone backup.
    /// </summary>
    public static Restored? Parse(string text, AppSettings current)
    {
        try
        {
            if (JsonNode.Parse(text) is not JsonObject j || (string?)j["app"] != "sabeel" || j["settings"] is not JsonObject settings)
                return null;
            var tracker = j["tracker"] as JsonObject ?? [];
            AppSettings? s;
            if (settings.ContainsKey("SchemaVersion"))
                s = SettingsSerializer.Deserialize(settings.ToJsonString());
            else
            {
                s = current.Clone();
                FromMobile(settings, s);
            }
            return new Restored(s, (JsonObject)tracker.DeepClone());
        }
        catch (Exception) { return null; }
    }

    private static void FromMobile(JsonObject m, AppSettings s)
    {
        T? Get<T>(string key)
        {
            try { return m[key] is JsonValue v && v.TryGetValue<T>(out var x) ? x : default; }
            catch { return default; }
        }
        int Int(string key, int dflt) => m[key] is JsonValue v && v.GetValueKind() == JsonValueKind.Number ? (int)v.GetValue<double>() : dflt;
        double Dbl(string key, double dflt) => m[key] is JsonValue v && v.GetValueKind() == JsonValueKind.Number ? v.GetValue<double>() : dflt;
        bool Bool(string key, bool dflt) => m[key] is JsonValue v && v.GetValueKind() is JsonValueKind.True or JsonValueKind.False ? v.GetValue<bool>() : dflt;

        s.KhatmaDays = Int("khatmaDays", s.KhatmaDays);
        s.KhatmaStart = Get<string>("khatmaStart") ?? s.KhatmaStart;
        s.KhatmaPage = Int("khatmaPage", s.KhatmaPage);
        s.KhatmaDone = Int("khatmaDone", s.KhatmaDone);
        s.GoldPrice = Dbl("goldPrice", s.GoldPrice);
        s.SilverPrice = Dbl("silverPrice", s.SilverPrice);
        s.NisabSilver = Bool("nisabSilver", s.NisabSilver);
        s.HijriAdjustmentDays = Int("hijriAdjust", s.HijriAdjustmentDays);
        s.WirdGoal = Int("wirdGoal", s.WirdGoal);
        if (Get<string>("palette") is { Length: > 0 } p && Content.Palette.All.Any(x => x.Id == p)) s.Palette = p;
    }
}
