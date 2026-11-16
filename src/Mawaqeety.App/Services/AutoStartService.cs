using Microsoft.Win32;

namespace Mawaqeety.App.Services;

/// <summary>Per-user auto start via HKCU\...\Run (no admin rights). Launches in background mode.</summary>
public static class AutoStartService
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Mawaqeety";

    private static string Command => $"\"{Environment.ProcessPath}\" {Program.BackgroundArg}";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(ValueName) is string;
    }

    public static void Enable()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
        key.SetValue(ValueName, Command);
    }

    public static void Disable()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        if (key?.GetValue(ValueName) is not null) key.DeleteValue(ValueName, throwOnMissingValue: false);
    }

    /// <summary>Keeps the registry in sync with the setting (also fixes the path after an update/move).</summary>
    public static void Apply(bool enabled)
    {
        if (enabled) Enable(); else Disable();
    }
}
