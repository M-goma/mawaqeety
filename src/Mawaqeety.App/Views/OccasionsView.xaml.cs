using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class OccasionsView : UserControl
{
    public OccasionsView()
    {
        InitializeComponent();
        Loaded += (_, _) => (DataContext as ViewModels.OccasionsViewModel)?.Reload();
    }
}
