using System.Diagnostics;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Mawaqeety.App.ViewModels;

namespace Mawaqeety.App.Services;

/// <summary>
/// "--smoke-test &lt;folder&gt;": opens every page (used by CI on Windows), saves a screenshot of each,
/// and records binding errors and exceptions in errors.txt. Exit code 1 when anything failed.
/// </summary>
public static class SmokeTest
{
    public const string Arg = "--smoke-test";

    private sealed class BindingErrors : TraceListener
    {
        public readonly List<string> Lines = [];
        public override void Write(string? message) { }
        public override void WriteLine(string? message) { if (message is not null) lock (Lines) Lines.Add(message); }
    }

    public static async Task RunAsync(App app, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var errors = new List<string>();
        var bindings = new BindingErrors();
        PresentationTraceSources.Refresh();
        PresentationTraceSources.DataBindingSource.Listeners.Add(bindings);
        PresentationTraceSources.DataBindingSource.Switch.Level = SourceLevels.Error;
        app.DispatcherUnhandledException += (_, e) => errors.Add("UI: " + e.Exception);

        async Task Step(string name, Func<Task> action)
        {
            try { await action(); }
            catch (Exception ex) { errors.Add($"{name}: {ex}"); }
        }

        void Shot(Window w, string name)
        {
            try
            {
                w.UpdateLayout();
                var dpi = VisualTreeHelper.GetDpi(w);
                var bmp = new RenderTargetBitmap((int)(w.ActualWidth * dpi.DpiScaleX), (int)(w.ActualHeight * dpi.DpiScaleY),
                    dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
                bmp.Render(w);
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(bmp));
                using var f = File.Create(Path.Combine(outDir, name + ".png"));
                enc.Save(f);
            }
            catch (Exception ex) { errors.Add($"screenshot {name}: {ex}"); }
        }

        await Step("start", async () =>
        {
            app.Settings.Update(s => { s.FirstRunCompleted = true; s.WidgetEnabled = false; s.MushafPage = 49; });
            app.ShowMainWindow();
            await Task.Delay(3000);
        });
        var w = Application.Current.Windows.OfType<Views.MainWindow>().First();
        w.Width = 1366;
        w.Height = 820;
        var vm = app.MainVm!;

        async Task Page(Page p, string name, int wait = 1500)
        {
            await Step(name, async () => { vm.Page = p; await Task.Delay(wait); Shot(w, name); });
        }

        await Page(ViewModels.Page.Dashboard, "01-dashboard");
        await Step("mushaf", async () =>
        {
            vm.Page = ViewModels.Page.Quran;
            vm.Quran.Mushaf.GoTo(49);
            await Task.Delay(9000); // pages come from the internet on first view
            Shot(w, "02-mushaf");
            vm.Quran.Mushaf.Select((3, 3));
            await Task.Delay(500);
            Shot(w, "03-mushaf-highlight");
            vm.Quran.Mushaf.Select(null);
            vm.Quran.Mushaf.ToneId = "sepia";
            await Task.Delay(1500);
            Shot(w, "04-mushaf-sepia");
            vm.Quran.Mushaf.ToneId = "auto";
            vm.Quran.DownloadsOpen = true;
            await Task.Delay(800);
            Shot(w, "05-downloads");
            vm.Quran.DownloadsOpen = false;
            vm.Quran.IndexOpen = true;
            vm.Quran.Filter = "الصبر";
            await Task.Delay(1500);
            Shot(w, "06-quran-index-search");
            vm.Quran.Filter = "";
            vm.Quran.IndexOpen = false;
        });
        await Page(ViewModels.Page.Adhkar, "07-adhkar");
        await Page(ViewModels.Page.Qibla, "08-qibla");
        await Step("tracker", async () =>
        {
            var today = app.Today;
            app.Tracker.SetPrayer(today, Core.Models.Prayer.Fajr, Core.Tracking.PrayerLog.Mosque);
            app.Tracker.SetPrayer(today.AddDays(-1), Core.Models.Prayer.Asr, Core.Tracking.PrayerLog.Jamaah);
            app.Tracker.SetAdhkar(today, morning: true);
            vm.Page = ViewModels.Page.Tasbeeh;
            await Task.Delay(800);
            for (var i = 0; i < 7; i++) vm.Tasbeeh.Count();
            await Task.Delay(800);
            Shot(w, "08b-tasbeeh");
            vm.Page = ViewModels.Page.Stats;
            await Task.Delay(1200);
            Shot(w, "08c-stats");
            vm.Page = ViewModels.Page.Dashboard;
            await Task.Delay(1500);
            Shot(w, "08d-dashboard-harvest");
            if (app.Tracker.Day(today).Tasbeeh < 7) errors.Add("tasbeeh did not count");
        });
        await Page(ViewModels.Page.Prophets, "09-prophets");
        await Step("stories-download", async () =>
        {
            await vm.Prophets.DownloadThisStoryCommand.ExecuteAsync(null);
            await Task.Delay(500);
            Shot(w, "09b-story-downloaded");
            if (!Services.DownloadManager.IsStorySaved("adam", "Male")) errors.Add("story download did not save adam (male)");
        });
        await Page(ViewModels.Page.Settings, "10-settings");
        await Step("palette", async () =>
        {
            vm.Settings.PaletteId = "royal";
            vm.Page = ViewModels.Page.Dashboard;
            await Task.Delay(1200);
            Shot(w, "11-palette-royal");
            vm.Settings.PaletteId = "emerald";
        });
        await Step("light", async () =>
        {
            vm.Settings.Theme = Core.Models.AppTheme.Light;
            vm.Page = ViewModels.Page.Quran;
            await Task.Delay(2500);
            Shot(w, "12-light-mushaf");
            vm.Settings.Theme = Core.Models.AppTheme.Dark;
        });
        await Step("widget", async () =>
        {
            vm.Settings.WidgetEnabled = true;
            await Task.Delay(1500);
            if (Application.Current.Windows.OfType<Views.WidgetWindow>().FirstOrDefault() is { } ww) Shot(ww, "13-widget");
            else errors.Add("widget window did not open");
            vm.Settings.WidgetEnabled = false;
        });

        lock (bindings.Lines) errors.AddRange(bindings.Lines.Distinct().Select(l => "binding: " + l));
        await File.WriteAllLinesAsync(Path.Combine(outDir, "errors.txt"), errors.Count == 0 ? ["OK"] : errors);
        app.Settings.SaveNow();
        app.Tray.Dispose();
        app.Shutdown(errors.Count == 0 ? 0 : 1);
    }
}
