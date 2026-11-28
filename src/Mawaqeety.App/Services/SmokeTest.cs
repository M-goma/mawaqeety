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

    private static T? FindChild<T>(DependencyObject root) where T : DependencyObject
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var c = VisualTreeHelper.GetChild(root, i);
            if (c is T t) return t;
            if (FindChild<T>(c) is { } x) return x;
        }
        return null;
    }

    private static IEnumerable<T> FindAll<T>(DependencyObject root) where T : DependencyObject
    {
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var c = VisualTreeHelper.GetChild(root, i);
            if (c is T t) yield return t;
            foreach (var x in FindAll<T>(c)) yield return x;
        }
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
        await Page(ViewModels.Page.Times, "01b-times");
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
        await Step("duas", async () =>
        {
            vm.Adhkar.ShowDuasCommand.Execute(null);
            vm.Adhkar.PickGroupCommand.Execute(vm.Adhkar.DuaGroups.First(g => g.Id == "travel"));
            await Task.Delay(1200);
            Shot(w, "07b-duas-travel");
            if (vm.Adhkar.Items.Count < 5) errors.Add("travel duas missing");
            vm.Adhkar.ShowMorningCommand.Execute(null);
        });
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
        await Step("hadith", async () =>
        {
            vm.Page = ViewModels.Page.Hadith;
            await Task.Delay(2500);
            Shot(w, "09c-hadith-today");
            vm.Hadith.Book = vm.Hadith.Books.First(b => b.Number == 78);
            await Task.Delay(2000);
            Shot(w, "09d-hadith-book");
            vm.Hadith.ShowFull = true;
            await Task.Delay(800);
            Shot(w, "09e-hadith-full");
            vm.Hadith.ShowFull = false;
            vm.Hadith.Query = "الكلمة الطيبة";
            vm.Hadith.SearchCommand.Execute(null);
            await Task.Delay(1500);
            if (vm.Hadith.Items.Count == 0) errors.Add("hadith search found nothing");
            vm.Page = ViewModels.Page.Companions;
            await Task.Delay(1200);
            Shot(w, "09f-companions");
        });
        await Page(ViewModels.Page.Settings, "10-settings");
        await Step("settings-backup", async () =>
        {
            if (FindChild<System.Windows.Controls.ScrollViewer>(w.PageHost) is { } sv) sv.ScrollToEnd();
            await Task.Delay(600);
            Shot(w, "10b-settings-backup");
            // Round trip through a backup file: the tracker comes back the same.
            var today = app.Today;
            app.Tracker.SetFast(today, true);
            var text = Core.Data.Backup.Export(app.Settings.Current, app.Tracker);
            await File.WriteAllTextAsync(Path.Combine(outDir, "backup-sample.json"), text);
            var r = Core.Data.Backup.Parse(text, app.Settings.Current);
            if (r is null) errors.Add("backup did not parse");
            else
            {
                vm.Settings.Restore(r);
                if (!app.Tracker.Day(today).Fast) errors.Add("backup restore lost today's fast");
                if (app.Tracker.ExportJson() != r.Tracker.ToJsonString()) errors.Add("backup tracker differs after restore");
            }
        });

        // ---------------- the new pages ----------------
        await Step("sabeel", async () =>
        {
            vm.Page = ViewModels.Page.Sabeel;
            await Task.Delay(1200);
            Shot(w, "14-sabeel");
            await vm.Sabeel.AskCommand.ExecuteAsync("تفسير آية الكرسي");
            await Task.Delay(1200);
            Shot(w, "14b-sabeel-kursi");
            if (vm.Sabeel.Ayat.Count != 1 || vm.Sabeel.Ayat[0].A.Ayah != 255) errors.Add("sabeel did not find ayat al-kursi");
            await vm.Sabeel.AskCommand.ExecuteAsync("الصبر");
            await Task.Delay(1200);
            Shot(w, "14c-sabeel-topic");
            if (vm.Sabeel.Ayat.Count == 0 || vm.Sabeel.Hadith.Count == 0) errors.Add("sabeel found nothing about patience");
            await vm.Sabeel.AskCommand.ExecuteAsync("ما حكم الربا");
            await Task.Delay(1000);
            Shot(w, "14d-sabeel-ruling");
            if (!vm.Sabeel.Ruling) errors.Add("sabeel did not mark a ruling question");
            await vm.Sabeel.AskCommand.ExecuteAsync("2:255");
            vm.Sabeel.OpenInMushafCommand.Execute(vm.Sabeel.Ayat[0]);
            await Task.Delay(4000);
            Shot(w, "14e-sabeel-open-mushaf");
            var mp = Core.Content.MushafIndex.Default.PageOf(2, 255);
            if (vm.Page != ViewModels.Page.Quran || (vm.Quran.Mushaf.RightPage != mp && vm.Quran.Mushaf.LeftPage != mp)) errors.Add("sabeel did not open the mushaf at 2:255");
        });
        await Step("ramadan", async () =>
        {
            // Seed last Ramadan and this month's white days.
            var adj = app.Settings.Current.HijriAdjustmentDays;
            var h = Core.HijriDate.From(app.Today, adj);
            var year = h.Month >= 9 ? h.Year : h.Year - 1;
            var start = Core.HijriDate.ToGregorian(year, 9, 1, adj);
            for (var i = 0; i < 27; i++)
            {
                var d = start.AddDays(i);
                if (d > app.Today) break;
                app.Tracker.SetFast(d, i != 6);
                if (i % 3 != 2) app.Tracker.SetTaraweeh(d, i < 20 ? 8 : 20);
                if (i >= 20 || i % 5 == 0) app.Tracker.SetTahajjud(d, true);
            }
            app.Tracker.SetTahajjud(app.Today, true);
            vm.Page = ViewModels.Page.Ramadan;
            await Task.Delay(1500);
            Shot(w, "15-ramadan");
            if (vm.Ramadan.Days.Count < 29) errors.Add("ramadan grid has too few days");
            var m = h.Day > 15 ? h.Month : h.Month - 1;
            if (m >= 1)
            {
                app.Tracker.SetFast(Core.HijriDate.ToGregorian(h.Year, m, 13, adj), true);
                app.Tracker.SetFast(Core.HijriDate.ToGregorian(h.Year, m, 14, adj), true);
            }
            vm.Page = ViewModels.Page.WhiteDays;
            await Task.Delay(1500);
            Shot(w, "16-white-days");
            if (vm.WhiteDays.Next.Count != 3) errors.Add("white days missing");
        });
        await Step("occasions", async () =>
        {
            vm.Page = ViewModels.Page.Occasions;
            await Task.Delay(1500);
            if (FindChild<System.Windows.Controls.Expander>(w.PageHost) is { } ex) ex.IsExpanded = true;
            await Task.Delay(600);
            Shot(w, "17-occasions");
            if (vm.Occasions.Items.Count != Core.Content.Occasions.All.Count) errors.Add("occasions missing");
        });
        await Step("asma", async () =>
        {
            vm.Page = ViewModels.Page.Asma;
            await Task.Delay(1500);
            Shot(w, "18-asma");
            vm.Asma.Query = "الرحم";
            vm.Asma.SelectCommand.Execute(vm.Asma.Items.FirstOrDefault());
            await Task.Delay(800);
            Shot(w, "18b-asma-search");
            if (vm.Asma.Items.Count == 0) errors.Add("asma search found nothing");
            vm.Asma.Query = "";
            vm.Asma.SelectCommand.Execute(vm.Asma.Items.First(x => x.Disputed));
            await Task.Delay(600);
            Shot(w, "18c-asma-disputed");
        });
        await Step("zakat", async () =>
        {
            vm.Page = ViewModels.Page.Zakat;
            await Task.Delay(1000);
            vm.Zakat.GoldPrice = "4000";
            vm.Zakat.SilverPrice = "50";
            vm.Zakat.Cash = "250000";
            vm.Zakat.Gold21 = "40";
            vm.Zakat.Debts = "15000";
            await Task.Delay(800);
            Shot(w, "19-zakat");
            if (vm.Zakat.HeroAmount == "—") errors.Add("zakat was not computed");
        });
        await Step("khatma", async () =>
        {
            vm.Khatma.Start(30);
            vm.Page = ViewModels.Page.Quran;
            vm.Quran.Mushaf.GoTo(1);
            await Task.Delay(1500);
            vm.Quran.Mushaf.GoTo(3);
            await Task.Delay(4000);
            Shot(w, "20-quran-wird");
            if (Core.Content.Khatma.PagesToday(app.Settings.Current, app.Today) < 2) errors.Add("mushaf pages were not counted for the wird");
            if (app.Tracker.Day(app.Today).Pages < 2) errors.Add("mushaf pages were not saved in the tracker");
            vm.Khatma.OpenCommand.Execute(null);
            await Task.Delay(1500);
            Shot(w, "20b-khatma");
            if (vm.Page != ViewModels.Page.Khatma) errors.Add("khatma page did not open");
        });
        await Step("sunan", async () =>
        {
            app.Tracker.SetSunnah(app.Today, Core.Tracking.Sunnah.Fajr, true);
            app.Tracker.SetSunnah(app.Today, Core.Tracking.Sunnah.Witr, true);
            app.Tracker.SetSunnah(app.Today.AddDays(-1), Core.Tracking.Sunnah.Duha, true);
            vm.Page = ViewModels.Page.Times;
            await Task.Delay(1200);
            if (FindChild<System.Windows.Controls.ScrollViewer>(w.PageHost) is { } sv) sv.ScrollToEnd();
            await Task.Delay(500);
            Shot(w, "21-times-sunan");
            if (vm.Times.Sunan.Items.Count(i => i.Done) != 2) errors.Add("sunan card does not show today's sunan");
            vm.Page = ViewModels.Page.Stats;
            await Task.Delay(1200);
            Shot(w, "21b-stats-sunan-pages");
        });
        // ---------------- pages ported from the mobile app's «المزيد» ----------------
        await Step("arbaeen", async () =>
        {
            vm.Page = ViewModels.Page.Arbaeen;
            await Task.Delay(1200);
            Shot(w, "23-arbaeen");
            vm.Arbaeen.Selected = vm.Arbaeen.Items[1];
            if (vm.Arbaeen.SahihLinks.FirstOrDefault() is { } link) await link.ToggleCommand.ExecuteAsync(null);
            await Task.Delay(1500);
            Shot(w, "23b-arbaeen-sahih");
            if (vm.Arbaeen.SahihLinks.FirstOrDefault() is { Text.Length: 0 }) errors.Add("arbaeen: the sahih narration did not load");
        });
        await Step("fiqh", async () =>
        {
            vm.Page = ViewModels.Page.Fiqh;
            await Task.Delay(1200);
            Shot(w, "24-fiqh");
            vm.Fiqh.Query = "التيمم";
            await Task.Delay(600);
            Shot(w, "24b-fiqh-search");
            if (vm.Fiqh.Items.Count == 0) errors.Add("fiqh search found nothing");
            vm.Fiqh.Query = "";
        });
        await Step("asbab", async () =>
        {
            vm.Page = ViewModels.Page.Asbab;
            await Task.Delay(1500);
            Shot(w, "25-asbab");
            if (vm.Asbab.Groups.Count == 0) errors.Add("asbab: no occasions for the first surah");
        });
        await Step("ghazawat", async () =>
        {
            vm.Page = ViewModels.Page.Ghazawat;
            await Task.Delay(4000); // the hadiths load in the background
            Shot(w, "26-ghazawat");
            if (vm.Ghazawat.Hadith.Any(h => h.Text.Length == 0)) errors.Add("ghazawat: hadith did not load");
        });
        await Page(ViewModels.Page.Nasab, "27-nasab");
        await Step("nasab-companion", async () =>
        {
            vm.Nasab.Companions[0].IsSelected = true;
            await Task.Delay(1000);
            Shot(w, "27b-nasab-abubakr");
            if (!vm.Nasab.Chain[vm.Nasab.Companions[0].C.Meet].IsHit) errors.Add("nasab: meeting point not marked");
            vm.Nasab.Companions[0].IsSelected = false;
        });
        await Page(ViewModels.Page.CompanionsIslam, "28-companions-islam");
        await Step("calendar", async () =>
        {
            vm.IsCalendar = true;
            await Task.Delay(1200);
            Shot(w, "29-calendar");
            if (vm.Calendar.Cells.Count(c => !c.IsBlank) < 28) errors.Add("calendar: month grid incomplete");
        });
        await Page(ViewModels.Page.Atlas, "30-atlas");

        await Step("new-palettes", async () =>
        {
            vm.Settings.PaletteId = "mocha";
            vm.Settings.Theme = Core.Models.AppTheme.Light;
            vm.Page = ViewModels.Page.Dashboard;
            await Task.Delay(1500);
            Shot(w, "22-palette-mocha-light");
            vm.Page = ViewModels.Page.Ramadan;
            await Task.Delay(1200);
            Shot(w, "22b-mocha-light-ramadan");
            vm.Settings.Theme = Core.Models.AppTheme.Dark;
            vm.Settings.PaletteId = "lavender";
            vm.Page = ViewModels.Page.Occasions;
            await Task.Delay(1200);
            Shot(w, "22c-palette-lavender");
            vm.Settings.PaletteId = "navy";
            vm.Page = ViewModels.Page.Settings;
            await Task.Delay(1200);
            if (FindAll<System.Windows.Controls.ItemsControl>(w.PageHost).FirstOrDefault(i => i.ItemsSource == vm.Settings.Palettes) is { } pal)
                pal.BringIntoView();
            await Task.Delay(600);
            Shot(w, "22d-palette-navy-settings");
            vm.Settings.PaletteId = "emerald";
        });
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
