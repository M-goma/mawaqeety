using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Mawaqeety.App.ViewModels;

public enum Page { Dashboard, Monthly, Settings, About }

public sealed partial class MainViewModel : ObservableObject
{
    public DashboardViewModel Dashboard { get; } = new();
    public MonthlyViewModel Monthly { get; } = new();
    public SettingsViewModel Settings { get; } = new();
    public AboutViewModel About { get; } = new();

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentView), nameof(IsDashboard), nameof(IsMonthly), nameof(IsSettings), nameof(IsAbout))]
    private Page _page = Page.Dashboard;

    public object CurrentView => Page switch
    {
        Page.Monthly => Monthly,
        Page.Settings => Settings,
        Page.About => About,
        _ => Dashboard,
    };

    public bool IsDashboard { get => Page == Page.Dashboard; set { if (value) Page = Page.Dashboard; } }
    public bool IsMonthly { get => Page == Page.Monthly; set { if (value) { Page = Page.Monthly; Monthly.Reload(); } } }
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
