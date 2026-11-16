using System.Text.Json;
using System.Text.Json.Serialization;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Core;

public static class SettingsSerializer
{
    public static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
        PropertyNameCaseInsensitive = true,
    };

    public static string Serialize(AppSettings s) => JsonSerializer.Serialize(s, Options);

    public static AppSettings Deserialize(string json)
    {
        var s = JsonSerializer.Deserialize<AppSettings>(json, Options) ?? new AppSettings();
        foreach (var p in PrayerExtensions.All) s.AlertFor(p); // ensure every prayer has an entry
        return s;
    }
}
