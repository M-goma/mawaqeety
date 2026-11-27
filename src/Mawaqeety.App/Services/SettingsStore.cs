using Mawaqeety.Core.Data;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>Holds the live settings, persists them to SQLite and notifies listeners.</summary>
public sealed class SettingsStore(AppDatabase db, IAppLog log)
{
    private readonly object _gate = new();
    private Timer? _debounce;

    public AppSettings Current { get; private set; } = db.LoadSettings();

    /// <summary>Raised (on the caller's thread) after any change. The bool is true when prayer times may have changed.</summary>
    public event Action<bool>? Changed;

    /// <summary>Applies a change, saves (debounced) and notifies.</summary>
    public void Update(Action<AppSettings> change, bool affectsTimes = false)
    {
        lock (_gate) change(Current);
        Changed?.Invoke(affectsTimes);
        ScheduleSave();
    }

    /// <summary>Replaces all settings (restoring a backup) and saves them.</summary>
    public void Replace(AppSettings settings)
    {
        lock (_gate) Current = settings;
        Changed?.Invoke(true);
        SaveNow();
    }

    private void ScheduleSave()
    {
        _debounce?.Dispose();
        _debounce = new Timer(_ => SaveNow(), null, 400, Timeout.Infinite);
    }

    public void SaveNow()
    {
        try
        {
            AppSettings snapshot;
            lock (_gate) snapshot = Current.Clone();
            db.SaveSettings(snapshot);
        }
        catch (Exception ex) { log.Error("Saving settings failed", ex); }
    }
}
