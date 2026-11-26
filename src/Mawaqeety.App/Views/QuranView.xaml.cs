using System.Windows.Controls;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class QuranView : UserControl
{
    public QuranView() => InitializeComponent();

    private void IndexList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (IndexList.SelectedItem is IndexItem item && DataContext is QuranViewModel vm)
        {
            vm.OpenIndexCommand.Execute(item);
            IndexList.SelectedItem = null;
        }
    }
}
