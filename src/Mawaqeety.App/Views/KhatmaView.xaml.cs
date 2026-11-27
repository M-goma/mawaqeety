using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class KhatmaView : UserControl
{
    public KhatmaView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.KhatmaViewModel)?.Reload();
    }
}
