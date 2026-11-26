using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class TasbeehView : UserControl
{
    public TasbeehView()
    {
        InitializeComponent();
        Loaded += (_, _) => Focus();
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key is Key.Space or Key.Enter && e.OriginalSource is not TextBox && DataContext is TasbeehViewModel vm)
            {
                vm.Count();
                e.Handled = true;
            }
        };
    }

    /// <summary>A click anywhere on the counter card counts (but not on its buttons and text box).</summary>
    private void Counter_Click(object sender, MouseButtonEventArgs e)
    {
        for (var d = e.OriginalSource as DependencyObject; d is not null && d != sender; d = d is System.Windows.Media.Visual ? System.Windows.Media.VisualTreeHelper.GetParent(d) : LogicalTreeHelper.GetParent(d))
            if (d is ButtonBase or TextBox) return;
        (DataContext as TasbeehViewModel)?.Count();
        Focus();
    }
}
