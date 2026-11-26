using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Mawaqeety.App.ViewModels;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.Views;

public partial class MushafView : UserControl
{
    public static readonly DependencyProperty PageHeightProperty =
        DependencyProperty.Register(nameof(PageHeight), typeof(double), typeof(MushafView), new PropertyMetadata(600.0));

    /// <summary>Height of one printed page on screen (fits the window, times the zoom).</summary>
    public double PageHeight { get => (double)GetValue(PageHeightProperty); set => SetValue(PageHeightProperty, value); }

    private MushafViewModel? Vm => DataContext as MushafViewModel;

    public MushafView()
    {
        InitializeComponent();
        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is MushafViewModel o) o.PropertyChanged -= Vm_PropertyChanged;
            if (e.NewValue is MushafViewModel n) n.PropertyChanged += Vm_PropertyChanged;
            Relayout();
        };
        Loaded += (_, _) => { Relayout(); Focus(); };
        PreviewKeyDown += OnKey;
        MouseDown += (_, _) => Focus();
    }

    private void Vm_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MushafViewModel.Zoom)) Relayout();
    }

    private void Stage_SizeChanged(object sender, SizeChangedEventArgs e) => Relayout();

    private void Relayout()
    {
        if (Vm is not { } vm || Stage.ActualHeight < 50) return;
        var fit = Math.Max(200, Stage.ActualHeight - 58); // room for the page header and number
        var pageWidth = fit * 1440 / 2330 + 16;
        // Two facing pages when they fit side by side, otherwise one page.
        vm.TwoPages = Stage.ActualWidth >= pageWidth * 2 * 0.92;
        PageHeight = fit * vm.Zoom;
    }

    private void Stage_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (Vm is not { } vm) return;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
        {
            if (e.Delta > 0) vm.ZoomInCommand.Execute(null); else vm.ZoomOutCommand.Execute(null);
            e.Handled = true;
            return;
        }
        if (vm.Zoom > 1.01) return; // scroll the enlarged page
        if (e.Delta < 0) vm.NextPageCommand.Execute(null); else vm.PrevPageCommand.Execute(null);
        e.Handled = true;
    }

    private void OnKey(object sender, KeyEventArgs e)
    {
        if (Vm is not { } vm || e.OriginalSource is TextBox || e.OriginalSource is ComboBox) return;
        var ctrl = Keyboard.Modifiers.HasFlag(ModifierKeys.Control);
        switch (e.Key)
        {
            // Arabic books open to the left: the left arrow goes forward.
            case Key.Left or Key.PageDown or Key.Space: vm.NextPageCommand.Execute(null); break;
            case Key.Right or Key.PageUp or Key.Back: vm.PrevPageCommand.Execute(null); break;
            case Key.OemPlus or Key.Add when ctrl: vm.ZoomInCommand.Execute(null); break;
            case Key.OemMinus or Key.Subtract when ctrl: vm.ZoomOutCommand.Execute(null); break;
            case Key.D0 or Key.NumPad0 when ctrl: vm.ZoomResetCommand.Execute(null); break;
            default: return;
        }
        e.Handled = true;
    }

    private void LookPopup_Closed(object sender, EventArgs e) => LookButton.IsChecked = false;

    /// <summary>Right-click on an ayah: listen from it, save the reading position, bookmark, copy.</summary>
    private void Page_MouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (Vm is not { } vm || sender is not FrameworkElement el || el.Tag is not MushafPageVm page) return;
        var pos = e.GetPosition(el);
        var box = vm.AyahAt(page.Number, pos.X, pos.Y);
        if (box is null) return;
        e.Handled = true;
        var q = vm.Quran;
        var (s, a) = (box.Surah, box.Ayah);
        vm.Select((s, a));
        var st = App.Instance.Settings.Current;
        var isRead = st.LastReadSurah == s && st.LastReadAyah == a;
        var marked = q.IsBookmarked(s, a);

        MenuItem Item(string header, string glyph, Action act)
        {
            var mi = new MenuItem
            {
                Header = header,
                Icon = new TextBlock { Text = glyph, FontFamily = new System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets") },
            };
            mi.Click += (_, _) => act();
            return mi;
        }

        var menu = new ContextMenu();
        menu.Items.Add(new MenuItem { Header = $"سورة {QuranRepository.Default[s].Name} • الآية {QuranRepository.ArabicDigits(a)}", IsEnabled = false });
        menu.Items.Add(new Separator());
        menu.Items.Add(Item("استماع من هذه الآية", "", () => q.StartRecitationAt(s, a)));
        menu.Items.Add(isRead
            ? Item("إزالة موضع القراءة", "", q.ClearLastRead)
            : Item("حفظ موضع القراءة هنا", "", () => q.SetLastRead(s, a)));
        menu.Items.Add(Item(marked ? "إزالة العلامة" : "إضافة علامة على الآية", "", () => q.ToggleBookmarkAt(s, a)));
        menu.Items.Add(Item("نسخ الآية", "", () => q.CopyAyahAt(s, a)));
        menu.Closed += (_, _) => vm.Select(null);
        menu.PlacementTarget = el;
        menu.IsOpen = true;
    }
}
