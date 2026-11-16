using System.Windows.Controls;
using Mawaqeety.App.ViewModels;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.Views;

public partial class SettingsView : UserControl
{
    public SettingsView() => InitializeComponent();

    private void Results_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (Results.SelectedItem is GeoLocation loc && DataContext is SettingsViewModel vm)
        {
            vm.SelectLocationCommand.Execute(loc);
            Results.SelectedItem = null;
        }
    }
}
