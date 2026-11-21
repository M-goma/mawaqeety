using Mawaqeety.Core.Models;
using Mawaqeety.Core.Scheduling;

namespace Mawaqeety.Core.Audio;

/// <summary>What to play for an alert: a user-chosen file, an adhan from the catalog, or the default chime.</summary>
public sealed record AlertSound(string? CustomPath, AdhanVoice? Adhan)
{
    public static readonly AlertSound Chime = new(null, null);
}

public static class AlertSoundResolver
{
    /// <summary>
    /// Priority: 1) custom file chosen for this prayer, 2) adhan (only when the prayer time starts, for the
    /// five prayers — never for reminders or sunrise), 3) built-in chime.
    /// </summary>
    public static AlertSound Resolve(Prayer prayer, AlertKind kind, AppSettings s)
    {
        var custom = s.AlertFor(prayer).SoundPath;
        if (!string.IsNullOrWhiteSpace(custom)) return new AlertSound(custom, null);
        if (kind == AlertKind.AtTime && prayer.IsObligatory() && s.AdhanEnabled)
        {
            var id = prayer == Prayer.Fajr ? s.FajrAdhanId : s.AdhanId;
            var voice = AdhanCatalog.Find(id)
                        ?? AdhanCatalog.Find(prayer == Prayer.Fajr ? AdhanCatalog.DefaultFajrId : AdhanCatalog.DefaultId);
            return new AlertSound(null, voice);
        }
        return AlertSound.Chime;
    }

    public static AlertSound Resolve(PlannedAlert a, AppSettings s) => Resolve(a.Prayer, a.Kind, s);
}
