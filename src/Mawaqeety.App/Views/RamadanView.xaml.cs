using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class RamadanView : UserControl
{
    public RamadanView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.RamadanViewModel)?.Reload();
    }
}
