using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class WhiteDaysView : UserControl
{
    public WhiteDaysView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.WhiteDaysViewModel)?.Reload();
    }
}
