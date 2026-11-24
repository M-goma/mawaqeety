using System.Windows.Controls;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class ProphetsView : UserControl
{
    public ProphetsView()
    {
        InitializeComponent();
        // Start each story from the top.
        DataContextChanged += (_, _) =>
        {
            if (DataContext is ProphetsViewModel vm)
                vm.PropertyChanged += (_, e) =>
                {
                    if (e.PropertyName == nameof(ProphetsViewModel.Selected)) StoryScroll.ScrollToTop();
                };
        };
    }
}
