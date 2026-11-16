using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.App.Localization;
using Mawaqeety.App.Services;

namespace Mawaqeety.App.ViewModels;

public sealed partial class AboutViewModel : ObservableObject
{
    public string Version => App.Instance.Updates.CurrentVersion;

    [ObservableProperty] private string _updateStatus = "";
    [ObservableProperty] private bool _isChecking;

    [RelayCommand]
    private async Task CheckUpdates()
    {
        IsChecking = true;
        try
        {
            var (result, version) = await App.Instance.Updates.CheckAndApplyAsync();
            UpdateStatus = result switch
            {
                UpdateResult.UpToDate => Loc.T("UpToDate"),
                UpdateResult.Updating => string.Format(Loc.T("UpdateAvailable"), version),
                UpdateResult.NotInstalled => Loc.T("UpdatesNotConfigured"),
                _ => Loc.T("UpdateFailed"),
            };
        }
        finally { IsChecking = false; }
    }
}
