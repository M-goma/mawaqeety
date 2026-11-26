using System.Net.Http;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using Mawaqeety.App.Localization;
using Mawaqeety.App.Services;
using Mawaqeety.App.ViewModels;
using Mawaqeety.App.Views;
using Mawaqeety.Core.Data;
using Mawaqeety.Core.Export;
using Mawaqeety.Core.Geo;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Scheduling;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App;

/// <summary>Composition root and application lifetime (tray-resident, window optional).</summary>
public partial class App : Application
{
    private readonly SingleInstance _instance;
    private readonly bool _startInBackground;
    private MainWindow? _window;
    private WidgetWindow? _widget;
    private DispatcherTimer? _trayTimer;
    private DispatcherTimer? _adhanTimer;
    private bool _exiting;

    public static App Instance => (App)Current;

    public FileLog Log { get; private set; } = null!;
    public AppDatabase Db { get; private set; } = null!;
    public SettingsStore Settings { get; private set; } = null!;
    public PrayerTimeService Times { get; private set; } = null!;
    public AlertScheduler Scheduler { get; private set; } = null!;
    public ToastService Toast { get; private set; } = null!;
    public SoundService Sound { get; private set; } = null!;
    public TrayService Tray { get; private set; } = null!;
    public LocationSearchService LocationSearch { get; private set; } = null!;
    public WindowsLocationService Location { get; private set; } = null!;
    public UpdateService Updates { get; private set; } = null!;
    public AdhanLibrary Adhan { get; private set; } = null!;
    public QuranAudioService Recitation { get; private set; } = null!;
    public NarrationService Narration { get; private set; } = null!;
    public MushafPages Pages { get; private set; } = null!;
    public DownloadManager Downloads { get; private set; } = null!;
    public HttpClient Http { get; private set; } = null!;
    public MainViewModel? MainVm { get; private set; }

    public App(SingleInstance instance, bool startInBackground)
    {
        _instance = instance;
        _startInBackground = startInBackground;
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Log = new FileLog(AppPaths.LogDir);
        Log.Info($"Mawaqeety starting (background={_startInBackground}, version={typeof(App).Assembly.GetName().Version})");
        HookGlobalExceptionHandlers();

        try
        {
            Db = new AppDatabase(AppPaths.DatabaseFile);
        }
        catch (Exception ex)
        {
            // Corrupted database: keep a copy for diagnosis and start fresh rather than refusing to run.
            Log.Error("Database open failed, recreating", ex);
            try { File.Move(AppPaths.DatabaseFile, AppPaths.DatabaseFile + $".broken-{DateTime.Now:yyyyMMddHHmmss}"); } catch { }
            Db = new AppDatabase(AppPaths.DatabaseFile);
        }

        Settings = new SettingsStore(Db, Log);
        var s = Settings.Current;
        Loc.I.SetLanguage(s.Language);
        ThemeService.Apply(s.Theme, s.Palette);

        Http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        Http.DefaultRequestHeaders.UserAgent.ParseAdd($"Mawaqeety/{typeof(App).Assembly.GetName().Version?.ToString(3)} (Windows desktop prayer times)");
        var aladhan = new AladhanClient(Http, Log);
        Times = new PrayerTimeService(Db, aladhan, Log);
        LocationSearch = new LocationSearchService(Http, aladhan, Log);
        Location = new WindowsLocationService(LocationSearch, Log);
        Updates = new UpdateService(Log);
        Adhan = new AdhanLibrary(Log);
        Recitation = new QuranAudioService(Dispatcher, Log, () => Settings.Current.ReciterId);
        Narration = new NarrationService(Dispatcher, Log) { PreferredGender = () => Settings.Current.NarrationVoice };

        Toast = new ToastService(Log);
        Pages = new MushafPages(Log);
        Downloads = new DownloadManager(Recitation, Pages, Toast, Log);
        Downloads.ProgressChanged += SetTaskbarProgress;
        Sound = new SoundService(Dispatcher, Log);
        Tray = new TrayService();
        WireTray();

        Scheduler = new AlertScheduler(Times, Db, new AlertSink(Dispatcher, Toast, Sound, Settings, Adhan), () => Settings.Current, log: Log);
        Scheduler.Start();

        Settings.Changed += affectsTimes =>
        {
            if (affectsTimes) Times.InvalidateMemory();
            Scheduler.Poke();
            Dispatcher.BeginInvoke(UpdateTray);
        };

        // Clock / time-zone / sleep changes: recompute immediately instead of waiting for the next tick.
        SystemEvents.TimeChanged += (_, _) => OnSystemTimeChanged("time changed");
        SystemEvents.PowerModeChanged += (_, ev) => { if (ev.Mode == PowerModes.Resume) OnSystemTimeChanged("resumed"); };
        SystemEvents.UserPreferenceChanged += (_, ev) =>
        {
            if (ev.Category == UserPreferenceCategory.General && Settings.Current.Theme == AppTheme.System)
                Dispatcher.BeginInvoke(() => ThemeService.Apply(AppTheme.System));
        };

        _instance.ListenForActivation(() => Dispatcher.BeginInvoke(ShowMainWindow));

        try { AutoStartService.Apply(s.StartWithWindows); }
        catch (Exception ex) { Log.Warn("Auto-start registry update failed", ex); }

        try { PdfExporter.Initialize(Directory.EnumerateFiles(AppPaths.FontsDir, "*.ttf").Select(File.OpenRead)); }
        catch (Exception ex) { Log.Warn("PDF font registration failed", ex); }

        _trayTimer = new DispatcherTimer(TimeSpan.FromSeconds(20), DispatcherPriority.Background, (_, _) => UpdateTray(), Dispatcher);
        _trayTimer.Start();
        // Retry adhan downloads later if the PC was offline at startup.
        _adhanTimer = new DispatcherTimer(TimeSpan.FromMinutes(15), DispatcherPriority.Background, (_, _) => _ = PrefetchAdhanAsync(), Dispatcher);
        _adhanTimer.Start();
        System.Net.NetworkInformation.NetworkChange.NetworkAvailabilityChanged += (_, ev) => { if (ev.IsAvailable) _ = PrefetchAdhanAsync(); };
        UpdateTray();
        UpdateWidget();

        _ = Task.Run(BackgroundMaintenanceAsync);

        // Auto-start passes --background; the "start in background" setting decides whether the window stays hidden.
        var showWindow = !_startInBackground || !s.StartMinimized || !s.FirstRunCompleted;
        if (showWindow) ShowMainWindow();

        if (!s.FirstRunCompleted)
        {
            Settings.Update(x => x.FirstRunCompleted = true);
        }

        var smoke = Array.IndexOf(Environment.GetCommandLineArgs(), SmokeTest.Arg);
        if (smoke > 0)
        {
            var args = Environment.GetCommandLineArgs();
            var dir = smoke + 1 < args.Length ? args[smoke + 1] : "smoke";
            Dispatcher.BeginInvoke(async () => await SmokeTest.RunAsync(this, dir));
        }
    }

    private void OnSystemTimeChanged(string reason)
    {
        Log.Info($"System event: {reason}");
        TimeZoneInfo.ClearCachedData();
        Times.InvalidateMemory();
        Scheduler.Poke();
        Dispatcher.BeginInvoke(() =>
        {
            UpdateTray();
            MainVm?.Refresh();
        });
    }

    private async Task BackgroundMaintenanceAsync()
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            Db.PruneLog(today.AddDays(-60));
            Db.PruneCache(today.AddMonths(-2));
            await PrefetchAdhanAsync();
            if (Settings.Current.Source == TimeSource.OnlineWithLocalFallback)
                await Times.SyncAsync(Settings.Current, today, CancellationToken.None);
        }
        catch (Exception ex) { Log.Warn("Background maintenance failed", ex); }
    }

    /// <summary>Downloads the selected adhan voices once, so they are ready offline at prayer time.</summary>
    public async Task PrefetchAdhanAsync()
    {
        var s = Settings.Current;
        if (!s.AdhanEnabled) return;
        foreach (var id in new[] { s.AdhanId, s.FajrAdhanId }.Distinct())
            if (Core.Audio.AdhanCatalog.Find(id) is { } v) await Adhan.EnsureAsync(v);
    }

    private void WireTray()
    {
        Tray.OpenRequested += () => Dispatcher.BeginInvoke(ShowMainWindow);
        Tray.ExitRequested += () => Dispatcher.BeginInvoke(ExitApp);
        Tray.StopSoundRequested += () => Sound.Stop();
        Tray.ResumeRequested += () => Settings.Update(s => s.PausedUntil = null);
        Tray.PauseRequested += span => Settings.Update(s =>
        {
            s.PausedUntil = span is { } d
                ? DateTimeOffset.Now.Add(d)
                : new DateTimeOffset(DateTime.Today.AddDays(1));
        });
        Sound.PlayingChanged += playing =>
        {
            Dispatcher.BeginInvoke(() => Tray.SetSoundPlaying(playing));
            if (playing) { Recitation.Pause(); Narration.Stop(); } // the adhan takes priority
        };
        Toast.OpenRequested += () => Dispatcher.BeginInvoke(ShowMainWindow);
        Tray.WidgetToggleRequested += () => Dispatcher.BeginInvoke(() =>
        {
            Settings.Update(s => s.WidgetEnabled = !s.WidgetEnabled);
            UpdateWidget();
        });
        Toast.StopSoundRequested += () => Sound.Stop();
    }

    public void UpdateTray()
    {
        try
        {
            var s = Settings.Current;
            var status = ComputeStatus(DateTimeOffset.Now);
            var line = string.Format(Loc.T("TrayNext"), Loc.I.Prayer(status.Next), Loc.I.FormatRemainingShort(status.Remaining))
                       + "  •  " + Loc.I.FormatTime(status.NextTime, s.Use24HourClock);
            var paused = s.PausedUntil is { } p && p > DateTimeOffset.Now;
            string? pausedLine = paused ? string.Format(Loc.T("AlertsPaused"), Loc.I.FormatTime(TimeZoneInfo.ConvertTime(s.PausedUntil!.Value, s.ResolveZone()), s.Use24HourClock)) : null;
            Tray.UpdateStatus(line, pausedLine, paused);
        }
        catch (Exception ex) { Log.Warn("Tray update failed", ex); }
    }

    public PrayerStatus ComputeStatus(DateTimeOffset now)
    {
        var s = Settings.Current;
        var zone = s.ResolveZone();
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(now, zone).DateTime);
        return PrayerStatusCalculator.Compute(now,
            Times.GetDay(today.AddDays(-1), s), Times.GetDay(today, s), Times.GetDay(today.AddDays(1), s));
    }

    public void ShowMainWindow()
    {
        if (_window is null)
        {
            MainVm ??= new MainViewModel();
            _window = new MainWindow(MainVm);
            _window.Closing += (_, ev) =>
            {
                if (_exiting || !Settings.Current.MinimizeToTrayOnClose) return;
                ev.Cancel = true;
                _window.Hide();
                MainVm.OnWindowHidden();
                Tray.ShowStillRunningHint();
            };
            _window.Closed += (_, _) =>
            {
                _window = null;
                if (!_exiting && !Settings.Current.MinimizeToTrayOnClose) ExitApp();
            };
        }
        _window.Show();
        if (_window.WindowState == WindowState.Minimized) _window.WindowState = WindowState.Normal;
        _window.Activate();
        _window.Topmost = true;  // reliably bring to front when activated from tray/second instance
        _window.Topmost = false;
        MainVm?.OnWindowShown();
    }

    /// <summary>Today's Hijri date in the current language.</summary>
    public string HijriToday()
    {
        var s = Settings.Current;
        var date = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.Now, s.ResolveZone()).DateTime);
        return Core.HijriDate.From(date, s.HijriAdjustmentDays).ToDisplay(Loc.I.IsArabic);
    }

    /// <summary>Download progress on the taskbar icon.</summary>
    private void SetTaskbarProgress(double? value)
    {
        if (_window is null) return;
        _window.TaskbarItemInfo ??= new System.Windows.Shell.TaskbarItemInfo();
        _window.TaskbarItemInfo.ProgressState = value is null ? System.Windows.Shell.TaskbarItemProgressState.None : System.Windows.Shell.TaskbarItemProgressState.Normal;
        _window.TaskbarItemInfo.ProgressValue = value ?? 0;
    }

    /// <summary>Shows, updates or closes the desktop widget according to the settings.</summary>
    public void UpdateWidget()
    {
        var s = Settings.Current;
        Tray.SetWidgetChecked(s.WidgetEnabled);
        if (!s.WidgetEnabled)
        {
            _widget?.Close();
            _widget = null;
            return;
        }
        if (_widget is null)
        {
            _widget = new WidgetWindow();
            _widget.Closed += (_, _) => _widget = null;
            _widget.Show();
        }
        _widget.ApplySettings();
    }

    public void ExitApp()
    {
        if (_exiting) return;
        _exiting = true;
        Log.Info("Exiting");
        Settings.SaveNow();
        _trayTimer?.Stop();
        _adhanTimer?.Stop();
        Sound.Stop();
        Recitation.Stop();
        Narration.Stop();
        Tray.Dispose();
        _widget?.Close();
        _window?.Close();
        try { Scheduler.DisposeAsync().AsTask().Wait(TimeSpan.FromSeconds(2)); } catch { }
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Log.Info("Exited");
        Log.Dispose();
        base.OnExit(e);
    }

    private void HookGlobalExceptionHandlers()
    {
        DispatcherUnhandledException += (_, e) =>
        {
            Log.Error("Unhandled UI exception", e.Exception);
            e.Handled = true; // keep the background reminder service alive
        };
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log.Error("Unhandled exception", e.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            Log.Error("Unobserved task exception", e.Exception);
            e.SetObserved();
        };
    }
}
