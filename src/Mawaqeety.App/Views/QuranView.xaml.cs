using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Views;

public partial class QuranView : UserControl
{
    private QuranViewModel? _vm;

    public QuranView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) => Attach();
        Loaded += (_, _) =>
        {
            Attach();
            // Show the last read position when the page opens.
            var s = App.Instance.Settings.Current;
            if (_vm is not null && s.LastReadSurah == _vm.SurahNumber && s.LastReadAyah > 0)
                ScrollTo(_vm.Ayahs.ElementAtOrDefault(s.LastReadAyah - 1));
        };
        Unloaded += (_, _) => { if (_vm is not null) _vm.ScrollRequested -= ScrollTo; _vm = null; };
    }

    private void Attach()
    {
        if (DataContext is not QuranViewModel vm || ReferenceEquals(vm, _vm)) return;
        if (_vm is not null) _vm.ScrollRequested -= ScrollTo;
        _vm = vm;
        _vm.ScrollRequested += ScrollTo;
    }

    private void ScrollTo(AyahItem? item)
    {
        if (item is null) return;
        Dispatcher.BeginInvoke(() =>
        {
            AyahList.UpdateLayout();
            if (item.Number == 1) AyahList.ScrollIntoView(item);
            else
            {
                // ScrollIntoView puts the item at the edge; scroll it to the top for comfortable reading.
                AyahList.ScrollIntoView(AyahList.Items[^1]);
                AyahList.UpdateLayout();
                AyahList.ScrollIntoView(item);
            }
            AyahList.SelectedItem = item;
        }, System.Windows.Threading.DispatcherPriority.Loaded);
    }

    private void IndexList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (IndexList.SelectedItem is IndexItem item && _vm is not null)
        {
            _vm.OpenIndexCommand.Execute(item);
            IndexList.SelectedItem = null;
        }
    }

    private void AyahList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (AyahList.SelectedItem is AyahItem a) _vm?.SaveLastReadCommand.Execute(a);
    }
}
