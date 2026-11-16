using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using Microsoft.Win32;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.Services;

public static class ThemeService
{
    private static readonly Uri DarkUri = new("pack://application:,,,/Themes/Colors.Dark.xaml");
    private static readonly Uri LightUri = new("pack://application:,,,/Themes/Colors.Light.xaml");

    public static bool IsDark { get; private set; } = true;

    public static void Apply(AppTheme theme)
    {
        IsDark = theme switch
        {
            AppTheme.Light => false,
            AppTheme.System => !WindowsUsesLightTheme(),
            _ => true,
        };
        var dicts = Application.Current.Resources.MergedDictionaries;
        var existing = dicts.FirstOrDefault(d => d.Source?.OriginalString.Contains("Colors.", StringComparison.OrdinalIgnoreCase) == true);
        var next = new ResourceDictionary { Source = IsDark ? DarkUri : LightUri };
        if (existing is null) dicts.Insert(0, next);
        else dicts[dicts.IndexOf(existing)] = next;

        foreach (Window w in Application.Current.Windows) ApplyTitleBar(w);
    }

    private static bool WindowsUsesLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int v && v == 1;
        }
        catch { return false; }
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    /// <summary>Dark/light native title bar (Windows 10 20H1+ and Windows 11).</summary>
    public static void ApplyTitleBar(Window w)
    {
        var hwnd = new WindowInteropHelper(w).Handle;
        if (hwnd == IntPtr.Zero) return;
        var dark = IsDark ? 1 : 0;
        if (DwmSetWindowAttribute(hwnd, 20, ref dark, sizeof(int)) != 0)
            DwmSetWindowAttribute(hwnd, 19, ref dark, sizeof(int)); // older Windows 10 builds
        var caption = IsDark ? 0x00360F07 : 0x00F4F6F3; // COLORREF (BGR) of the window background, Windows 11 only
        DwmSetWindowAttribute(hwnd, 35, ref caption, sizeof(int));
    }
}
