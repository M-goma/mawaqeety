using System.ComponentModel;
using System.Windows.Controls;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class AsbabView : UserControl
{
    public AsbabView()
    {
        InitializeComponent();
        // Start each surah from the top.
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is INotifyPropertyChanged old) old.PropertyChanged -= OnVmChanged;
            if (e.NewValue is AsbabViewModel vm) vm.PropertyChanged += OnVmChanged;
        };
    }

    private void OnVmChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(AsbabViewModel.Selected)) Scroll.ScrollToTop();
    }
}
