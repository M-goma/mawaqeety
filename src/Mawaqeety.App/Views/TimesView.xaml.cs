using System.Windows;
using System.Windows.Controls;
using Mawaqeety.App.ViewModels;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.App.Views;

public partial class TimesView : UserControl
{
    public TimesView() => InitializeComponent();

    private DashboardViewModel? Vm => (DataContext as TimesViewModel)?.Dash;

    /// <summary>"How did you pray it?" menu next to each prayer.</summary>
    private void Log_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button b || b.Tag is not PrayerRowViewModel row || Vm is not { } vm) return;
        var menu = new ContextMenu { PlacementTarget = b, Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom };
        menu.Items.Add(new MenuItem { Header = $"صلاة {row.Name} — كيف صليتها؟", IsEnabled = false });
        menu.Items.Add(new Separator());
        foreach (var l in new[] { PrayerLog.Mosque, PrayerLog.Jamaah, PrayerLog.Alone, PrayerLog.Qada })
        {
            var mi = new MenuItem { Header = $"{l.Emoji()}  {l.LongLabel()}", IsCheckable = true, IsChecked = row.Log == l };
            mi.Click += (_, _) => vm.LogPrayer(row, l);
            menu.Items.Add(mi);
        }
        if (row.Log != PrayerLog.None)
        {
            menu.Items.Add(new Separator());
            var undo = new MenuItem { Header = "إلغاء التسجيل" };
            undo.Click += (_, _) => vm.LogPrayer(row, PrayerLog.None);
            menu.Items.Add(undo);
        }
        menu.IsOpen = true;
    }

}
