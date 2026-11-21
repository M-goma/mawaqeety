using Mawaqeety.Core.Services;
using Velopack;
using Velopack.Sources;

namespace Mawaqeety.App.Services;

public enum UpdateResult { NotInstalled, UpToDate, Updating, Failed }

/// <summary>
/// Updates via Velopack. Set <see cref="FeedUrl"/> to the folder/URL where `vpk pack` output is uploaded
/// (e.g. a GitHub Releases page or any static web host). See docs/BUILD.md.
/// </summary>
public sealed class UpdateService(IAppLog log)
{
    public const string FeedUrl = "https://github.com/M-goma/mawaqeety/raw/main/download";

    public string CurrentVersion =>
        typeof(UpdateService).Assembly.GetName().Version?.ToString(3) ?? "1.0.0";

    public async Task<(UpdateResult Result, string? Version)> CheckAndApplyAsync()
    {
        try
        {
            var mgr = new UpdateManager(new SimpleWebSource(FeedUrl));
            if (!mgr.IsInstalled) return (UpdateResult.NotInstalled, null);
            var info = await mgr.CheckForUpdatesAsync();
            if (info is null) return (UpdateResult.UpToDate, null);
            await mgr.DownloadUpdatesAsync(info);
            log.Info($"Applying update {info.TargetFullRelease.Version}");
            mgr.ApplyUpdatesAndRestart(info);
            return (UpdateResult.Updating, info.TargetFullRelease.Version.ToString());
        }
        catch (Exception ex)
        {
            log.Warn("Update check failed", ex);
            return (UpdateResult.Failed, null);
        }
    }
}
