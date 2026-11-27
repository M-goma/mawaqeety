using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Mawaqeety.Core.Content;
using Microsoft.Win32;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.Services;

public static class ThemeService
{
    private static readonly Uri DarkUri = new("pack://application:,,,/Themes/Colors.Dark.xaml");
    private static readonly Uri LightUri = new("pack://application:,,,/Themes/Colors.Light.xaml");

    public static bool IsDark { get; private set; } = true;
    private static string _palette = "emerald";

    /// <summary>Raised after the colours change (e.g. so the Mushaf can re-tint its pages).</summary>
    public static event Action? Changed;

    public static void Apply(AppTheme theme, string? palette = null)
    {
        if (palette is not null) _palette = palette;
        IsDark = theme switch
        {
            AppTheme.Light => false,
            AppTheme.System => !WindowsUsesLightTheme(),
            _ => true,
        };
        var dicts = Application.Current.Resources.MergedDictionaries;
        var existing = dicts.FirstOrDefault(d => d.Source?.OriginalString.Contains("Colors.", StringComparison.OrdinalIgnoreCase) == true);
        var next = new ResourceDictionary { Source = IsDark ? DarkUri : LightUri };
        ApplyPalette(next, Palette.Find(_palette), IsDark);
        if (existing is null) dicts.Insert(0, next);
        else dicts[dicts.IndexOf(existing)] = next;

        foreach (Window w in Application.Current.Windows) ApplyTitleBar(w);
        Changed?.Invoke();
    }

    public static Color Parse(string hex) => (Color)ColorConverter.ConvertFromString(hex);

    public static Color Mix(Color a, Color b, double t) => Color.FromArgb(255,
        (byte)Math.Round(a.R + (b.R - a.R) * t), (byte)Math.Round(a.G + (b.G - a.G) * t), (byte)Math.Round(a.B + (b.B - a.B) * t));

    private static Color Alpha(Color c, byte a) => Color.FromArgb(a, c.R, c.G, c.B);

    /// <summary>Overrides the accent colours (and, at night, the background shades) with one of the ten styles.</summary>
    private static void ApplyPalette(ResourceDictionary d, Palette p, bool dark)
    {
        Color bg = Parse(p.Bg), surface = Parse(p.Surface), surface2 = Parse(p.Surface2), primary = Parse(p.Primary),
              accent = Parse(p.Accent), heroText = Parse(p.HeroText);
        void Set(string key, Color c) { var b = new SolidColorBrush(c); b.Freeze(); d[key] = b; }

        if (dark)
        {
            d["BgColor"] = bg;
            Set("BgBrush", bg);
            Set("SidebarBrush", Mix(bg, surface, 0.45));
            Set("SurfaceBrush", surface);
            Set("Surface2Brush", surface2);
            Set("InputBrush", Mix(bg, surface, 0.6));
            Set("LineBrush", Mix(surface, primary, 0.18));
            Set("HoverBrush", Mix(surface, surface2, 0.6));
            Set("AccentBrush", primary);
            Set("AccentHoverBrush", Mix(primary, Colors.White, 0.12));
            Set("GoldBrush", accent);
        }
        else
        {
            Set("SidebarBrush", Mix(bg, surface, 0.45));
            Set("AccentBrush", Mix(primary, Colors.Black, 0.15));
            Set("AccentHoverBrush", Mix(primary, Colors.Black, 0.25));
            Set("GoldBrush", p.LightAccent is { } la ? Parse(la) : Mix(accent, Colors.Black, 0.22));
            Set("HoverBrush", Mix(Colors.White, primary, 0.08));
            if (p.LightBase is { } lb)
            {
                // A tinted light mode (e.g. beige for the coffee palettes), as in the mobile app.
                Color lbg = Parse(lb), card = p.LightCard is { } lc ? Parse(lc) : Colors.White;
                d["BgColor"] = lbg;
                Set("BgBrush", lbg);
                Set("SurfaceBrush", card);
                Set("Surface2Brush", Mix(lbg, card, 0.45));
                Set("InputBrush", card);
                Set("LineBrush", Mix(card, primary, 0.16));
                Set("HoverBrush", Mix(card, primary, 0.10));
            }
        }
        Set("AccentSoftBrush", Alpha(primary, 0x1A));
        Set("GoldSoftBrush", Alpha(accent, dark ? (byte)0x26 : (byte)0x33));
        Set("HeroMutedBrush", heroText);
        var hero = new LinearGradientBrush { StartPoint = new(0, 0), EndPoint = new(1, 1) };
        for (var i = 0; i < p.Hero.Count; i++)
            hero.GradientStops.Add(new GradientStop(Parse(p.Hero[i]), p.Hero.Count == 3 ? new[] { 0, 0.55, 1 }[i] : i / (double)Math.Max(1, p.Hero.Count - 1)));
        hero.Freeze();
        d["HeroBrush"] = hero;
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
        var pal = Palette.Find(_palette);
        var bgc = IsDark ? Parse(pal.Bg) : pal.LightBase is { } lb ? Parse(lb) : Color.FromRgb(0xF3, 0xF6, 0xF4);
        var caption = bgc.R | (bgc.G << 8) | (bgc.B << 16); // COLORREF (BGR) of the window background, Windows 11 only
        DwmSetWindowAttribute(hwnd, 35, ref caption, sizeof(int));
    }
}
