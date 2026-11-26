using CommunityToolkit.Mvvm.ComponentModel;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>
/// Saves recitations (ayah by ayah) and Mushaf pages for offline use. Keeps running while the window is closed
/// (the app stays in the tray), shows its progress on the taskbar icon and sends a Windows notification at the end.
/// </summary>
public sealed partial class DownloadManager(QuranAudioService recitation, MushafPages pages, ToastService toast, IAppLog log) : ObservableObject
{
    private CancellationTokenSource? _quranCts, _mushafCts;
    private int _quranDone, _quranTotal, _mushafDone;

    [ObservableProperty] private bool _quranRunning;
    [ObservableProperty] private bool _mushafRunning;
    [ObservableProperty] private string _quranText = "";
    [ObservableProperty] private string _mushafText = "";

    public bool Any => QuranRunning || MushafRunning;

    /// <summary>0..1 over everything that is downloading, or null when nothing is.</summary>
    public event Action<double?>? ProgressChanged;

    private void Report()
    {
        OnPropertyChanged(nameof(Any));
        double done = 0, total = 0;
        if (QuranRunning) { done += _quranDone; total += _quranTotal; }
        if (MushafRunning) { done += _mushafDone; total += MushafIndex.PageCount; }
        ProgressChanged?.Invoke(Any && total > 0 ? done / total : null);
    }

    private static string Pct(int done, int total) => QuranRepository.ArabicDigits(total == 0 ? 0 : (int)(done * 100L / total)) + "٪";

    /// <summary>How many ayah files of a reciter are on the device (out of 6236 + the basmala).</summary>
    public static int SavedAyahs(string reciter)
    {
        var dir = Path.Combine(AppPaths.DataDir, "quran", reciter);
        try { return Directory.Exists(dir) ? Directory.EnumerateFiles(dir, "*.mp3").Count() : 0; }
        catch { return 0; }
    }

    public static bool IsSurahSaved(string reciter, int surah)
    {
        var dir = Path.Combine(AppPaths.DataDir, "quran", reciter);
        var n = QuranRepository.Default[surah].Verses.Count;
        return Enumerable.Range(1, n).All(a => File.Exists(Path.Combine(dir, Reciters.FileName(surah, a))));
    }

    /// <summary>Downloads the given surahs (all when null) with one reciter. Files already saved are skipped.</summary>
    public async Task DownloadRecitationAsync(string reciter, IReadOnlyList<int>? surahs = null)
    {
        if (QuranRunning) return;
        var list = surahs ?? Enumerable.Range(1, 114).ToList();
        var files = new List<(int S, int A)> { (1, 1) }; // the basmala plays before most surahs
        foreach (var s in list)
            for (var a = 1; a <= QuranRepository.Default[s].Verses.Count; a++)
                if (s != 1 || a != 1) files.Add((s, a));
        _quranCts = new CancellationTokenSource();
        var ct = _quranCts.Token;
        _quranDone = 0;
        _quranTotal = files.Count;
        QuranRunning = true;
        var name = Reciters.Find(reciter).Name;
        var what = surahs is null ? "القرآن كاملًا" : list.Count == 1 ? $"سورة {QuranRepository.Default[list[0]].Name}" : $"{QuranRepository.ArabicDigits(list.Count)} سورة";
        QuranText = $"جارٍ تنزيل {what} بصوت {name}…";
        Report();
        var failed = 0;
        var queue = new Queue<(int S, int A)>(files);
        var gate = new object();
        async Task Worker()
        {
            while (!ct.IsCancellationRequested)
            {
                (int S, int A) f;
                lock (gate) { if (queue.Count == 0) return; f = queue.Dequeue(); }
                if (await recitation.EnsureAsync(reciter, f.S, f.A) is null) Interlocked.Increment(ref failed);
                var done = Interlocked.Increment(ref _quranDone);
                if (done % 10 == 0 || done == _quranTotal)
                    _ = App.Instance.Dispatcher.BeginInvoke(() =>
                    {
                        QuranText = $"تنزيل {what} بصوت {name}: {Pct(_quranDone, _quranTotal)} ({QuranRepository.ArabicDigits(_quranDone)} من {QuranRepository.ArabicDigits(_quranTotal)} آية)";
                        Report();
                    });
            }
        }
        try { await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => Task.Run(Worker))); }
        catch (Exception ex) { log.Warn("Recitation download failed", ex); }
        QuranRunning = false;
        if (ct.IsCancellationRequested) QuranText = "تم إيقاف التنزيل. ما نُزِّل محفوظ، ويكمل من حيث توقف.";
        else if (failed > 0)
        {
            QuranText = $"تعذّر تنزيل {QuranRepository.ArabicDigits(failed)} آية. تأكد من الاتصال ثم أعد المحاولة.";
            toast.Show("توقّف التنزيل", QuranText, tag: "download");
        }
        else
        {
            QuranText = $"✓ {what} بصوت {name} جاهز دون إنترنت.";
            toast.Show("✓ اكتمل التنزيل", $"{what} بصوت {name} جاهز للاستماع دون إنترنت.", tag: "download");
        }
        Report();
    }

    /// <summary>Saves every Mushaf page that is not on the device yet.</summary>
    public async Task DownloadMushafAsync()
    {
        if (MushafRunning) return;
        _mushafCts = new CancellationTokenSource();
        var ct = _mushafCts.Token;
        var missing = new Queue<int>(Enumerable.Range(1, MushafIndex.PageCount).Where(p => !pages.IsSaved(p)));
        _mushafDone = MushafIndex.PageCount - missing.Count;
        MushafRunning = true;
        MushafText = "جارٍ تنزيل صفحات المصحف…";
        Report();
        var failed = 0;
        var gate = new object();
        async Task Worker()
        {
            while (!ct.IsCancellationRequested)
            {
                int p;
                lock (gate) { if (missing.Count == 0) return; p = missing.Dequeue(); }
                if (await pages.LoadAsync(p) is null) Interlocked.Increment(ref failed);
                var done = Interlocked.Increment(ref _mushafDone);
                if (done % 4 == 0 || done == MushafIndex.PageCount)
                    _ = App.Instance.Dispatcher.BeginInvoke(() =>
                    {
                        MushafText = $"تنزيل صفحات المصحف: {QuranRepository.ArabicDigits(_mushafDone)} من {QuranRepository.ArabicDigits(MushafIndex.PageCount)}";
                        Report();
                    });
            }
        }
        try { await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => Task.Run(Worker))); }
        catch (Exception ex) { log.Warn("Mushaf download failed", ex); }
        MushafRunning = false;
        if (ct.IsCancellationRequested) MushafText = "تم إيقاف التنزيل. ما نُزِّل محفوظ.";
        else if (failed > 0) MushafText = $"تعذّر تنزيل {QuranRepository.ArabicDigits(failed)} صفحة. أعد المحاولة.";
        else
        {
            MushafText = "✓ صفحات المصحف كلها محفوظة للقراءة دون إنترنت.";
            toast.Show("✓ اكتمل تنزيل المصحف", "٦٠٤ صفحة جاهزة للقراءة دون إنترنت.", tag: "download");
        }
        Report();
    }

    public void CancelRecitation() => _quranCts?.Cancel();
    public void CancelMushaf() => _mushafCts?.Cancel();
}
