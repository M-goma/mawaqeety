using System.ComponentModel;
using System.Windows.Controls;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class ArbaeenView : UserControl
{
    public ArbaeenView()
    {
        InitializeComponent();
        // Start each hadith from the top.
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is INotifyPropertyChanged old) old.PropertyChanged -= OnVmChanged;
            if (e.NewValue is ArbaeenViewModel vm) vm.PropertyChanged += OnVmChanged;
        };
    }

    private void OnVmChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ArbaeenViewModel.Selected)) Scroll.ScrollToTop();
    }
}
