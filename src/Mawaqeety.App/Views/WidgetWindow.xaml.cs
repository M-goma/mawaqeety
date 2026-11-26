using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Mawaqeety.App.Localization;
using Mawaqeety.App.Services;

namespace Mawaqeety.App.Views;

/// <summary>Small desktop window: the clock and the time left to the next prayer. Drag to move; right-click for options.</summary>
public partial class WidgetWindow : Window
{
    private readonly DispatcherTimer _timer;

    public WidgetWindow()
    {
        InitializeComponent();
        _timer = new DispatcherTimer(TimeSpan.FromSeconds(1), DispatcherPriority.Background, (_, _) => Tick(), Dispatcher);
        Loaded += (_, _) =>
        {
            PlaceOnScreen();
            Tick();
            _timer.Start();
        };
        Closed += (_, _) => _timer.Stop();
        SourceInitialized += (_, _) => ThemeService.ApplyTitleBar(this);
    }

    public void ApplySettings()
    {
        var s = App.Instance.Settings.Current;
        Topmost = s.WidgetTopmost;
        TopmostItem.IsChecked = s.WidgetTopmost;
    }

    private void PlaceOnScreen()
    {
        var s = App.Instance.Settings.Current;
        var area = SystemParameters.WorkArea;
        UpdateLayout();
        var w = ActualWidth > 0 ? ActualWidth : Width;
        var h = ActualHeight > 0 ? ActualHeight : 140;
        // Default: bottom-right corner, above the clock in the taskbar.
        var left = s.WidgetLeft ?? area.Right - w - 12;
        var top = s.WidgetTop ?? area.Bottom - h - 12;
        // Keep it visible if the screen layout changed.
        Left = Math.Clamp(left, SystemParameters.VirtualScreenLeft, SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth - w);
        Top = Math.Clamp(top, SystemParameters.VirtualScreenTop, SystemParameters.VirtualScreenTop + SystemParameters.VirtualScreenHeight - h);
        ApplySettings();
    }

    private void Tick()
    {
        try
        {
            var app = App.Instance;
            var s = app.Settings.Current;
            var now = DateTimeOffset.Now;
            var local = TimeZoneInfo.ConvertTime(now, s.ResolveZone());
            Clock.Text = local.ToString(s.Use24HourClock ? "HH:mm:ss" : "h:mm:ss", System.Globalization.CultureInfo.InvariantCulture) + (s.Use24HourClock ? "" : (local.Hour < 12 ? (Loc.I.IsArabic ? " ص" : " AM") : (Loc.I.IsArabic ? " م" : " PM")));
            Date.Text = local.ToString("dddd d MMMM", Loc.I.Culture) + "  •  " + app.HijriToday();
            var st = app.ComputeStatus(now);
            NextName.Text = Loc.I.IsArabic ? $"المتبقي على {Loc.I.Prayer(st.Next)}" : $"Time to {Loc.I.Prayer(st.Next)}";
            NextTime.Text = (Loc.I.IsArabic ? "الأذان " : "at ") + Loc.I.FormatTime(st.NextTime, s.Use24HourClock);
            var r = st.Remaining < TimeSpan.Zero ? TimeSpan.Zero : st.Remaining;
            Countdown.Text = $"{(int)r.TotalHours:00}:{r.Minutes:00}:{r.Seconds:00}";
        }
        catch (Exception ex) { App.Instance.Log.Warn("Widget update failed", ex); }
    }

    private void Card_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2) { App.Instance.ShowMainWindow(); return; }
        try { DragMove(); } catch (InvalidOperationException) { return; }
        App.Instance.Settings.Update(s => { s.WidgetLeft = Left; s.WidgetTop = Top; });
    }

    private void Open_Click(object sender, RoutedEventArgs e) => App.Instance.ShowMainWindow();

    private void Topmost_Click(object sender, RoutedEventArgs e)
    {
        App.Instance.Settings.Update(s => s.WidgetTopmost = TopmostItem.IsChecked);
        ApplySettings();
    }

    private void Hide_Click(object sender, RoutedEventArgs e)
    {
        App.Instance.Settings.Update(s => s.WidgetEnabled = false);
        App.Instance.UpdateWidget();
    }
}
