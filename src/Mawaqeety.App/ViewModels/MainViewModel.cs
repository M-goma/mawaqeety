using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Mawaqeety.App.ViewModels;

public enum Page { Dashboard, Monthly, Quran, Adhkar, Qibla, Prophets, Settings, About }

public sealed partial class MainViewModel : ObservableObject
{
    public DashboardViewModel Dashboard { get; } = new();
    public MonthlyViewModel Monthly { get; } = new();
    public SettingsViewModel Settings { get; } = new();
    public QuranViewModel Quran => _quran ??= new QuranViewModel();
    public ProphetsViewModel Prophets => _prophets ??= new ProphetsViewModel();
    private QuranViewModel? _quran;
    private ProphetsViewModel? _prophets;
    public AdhkarViewModel Adhkar => _adhkar ??= new AdhkarViewModel();
    public QiblaViewModel Qibla => _qibla ??= new QiblaViewModel();
    private AdhkarViewModel? _adhkar;
    private QiblaViewModel? _qibla;
    public AboutViewModel About { get; } = new();

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentView), nameof(IsDashboard), nameof(IsMonthly), nameof(IsQuran), nameof(IsAdhkar), nameof(IsQibla), nameof(IsProphets), nameof(IsSettings), nameof(IsAbout))]
    private Page _page = Page.Dashboard;

    public object CurrentView => Page switch
    {
        Page.Monthly => Monthly,
        Page.Quran => Quran,
        Page.Adhkar => Adhkar,
        Page.Qibla => Qibla,
        Page.Prophets => Prophets,
        Page.Settings => Settings,
        Page.About => About,
        _ => Dashboard,
    };

    public bool IsDashboard { get => Page == Page.Dashboard; set { if (value) Page = Page.Dashboard; } }
    public bool IsMonthly { get => Page == Page.Monthly; set { if (value) { Page = Page.Monthly; Monthly.Reload(); } } }
    public bool IsQuran { get => Page == Page.Quran; set { if (value) Page = Page.Quran; } }
    public bool IsAdhkar { get => Page == Page.Adhkar; set { if (value) Page = Page.Adhkar; } }
    public bool IsQibla { get => Page == Page.Qibla; set { if (value) Page = Page.Qibla; } }
    public bool IsProphets { get => Page == Page.Prophets; set { if (value) Page = Page.Prophets; } }
    public bool IsSettings { get => Page == Page.Settings; set { if (value) Page = Page.Settings; } }
    public bool IsAbout { get => Page == Page.About; set { if (value) Page = Page.About; } }

    [RelayCommand]
    private void Navigate(Page page)
    {
        if (page == Page.Monthly) Monthly.Reload();
        Page = page;
    }

    public void OnWindowShown() => Dashboard.Start();
    public void OnWindowHidden() => Dashboard.Stop();

    public void Refresh()
    {
        Dashboard.Reload();
        Monthly.Reload();
    }
}
