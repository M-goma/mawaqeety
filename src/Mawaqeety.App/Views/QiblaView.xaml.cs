using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class QiblaView : UserControl
{
    public QiblaView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.QiblaViewModel)?.Reload();
    }
}
