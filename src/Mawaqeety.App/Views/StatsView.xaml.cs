using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class StatsView : UserControl
{
    public StatsView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.StatsViewModel)?.Reload();
    }
}
