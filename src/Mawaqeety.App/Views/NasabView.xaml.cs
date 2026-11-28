using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class NasabView : UserControl
{
    public NasabView()
    {
        InitializeComponent();
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is NasabViewModel old) old.MeetRequested -= OnMeet;
            if (e.NewValue is NasabViewModel vm) vm.MeetRequested += OnMeet;
        };
    }

    /// <summary>Scrolls the tree to the ancestor where the selected companion's lineage meets the Prophet's.</summary>
    private void OnMeet(int index)
    {
        if (index < 0) return;
        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>
        {
            if (Tree.ItemContainerGenerator.ContainerFromIndex(index) is FrameworkElement node)
                node.BringIntoView(new Rect(0, -120, node.ActualWidth, node.ActualHeight + 240));
        });
    }
}
