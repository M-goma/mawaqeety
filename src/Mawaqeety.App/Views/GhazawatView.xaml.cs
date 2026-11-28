using System.ComponentModel;
using System.Windows.Controls;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class GhazawatView : UserControl
{
    public GhazawatView()
    {
        InitializeComponent();
        // Start each battle from the top.
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is INotifyPropertyChanged old) old.PropertyChanged -= OnVmChanged;
            if (e.NewValue is GhazawatViewModel vm) vm.PropertyChanged += OnVmChanged;
        };
    }

    private void OnVmChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(GhazawatViewModel.Selected)) Scroll.ScrollToTop();
    }
}
