using System.Windows;
using System.Windows.Controls;

namespace Mawaqeety.App.Views;

public partial class HadithView : UserControl
{
    public HadithView() => InitializeComponent();
    private ViewModels.HadithViewModel? Vm => DataContext as ViewModels.HadithViewModel;
    private void TextOnly_Click(object sender, RoutedEventArgs e) { if (Vm is { } v) v.ShowFull = false; }
    private void Full_Click(object sender, RoutedEventArgs e) { if (Vm is { } v) v.ShowFull = true; }
}
