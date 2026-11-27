using System.Net.Http;
using System.Windows.Threading;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>
/// Verse-by-verse Qur'an recitation. Each ayah file is downloaded once into
/// %AppData%\Mawaqeety\quran\{reciter}\ and then works offline; the next ayah is prefetched
/// so playback is gapless. Raises <see cref="AyahStarted"/> so the reader can highlight and scroll.
/// </summary>
public sealed class QuranAudioService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(2) };
    private readonly Dispatcher _dispatcher;
    private readonly IAppLog _log;
    private readonly Func<string> _reciter;
    private readonly MediaSession _media;
    private List<(int Surah, int Ayah, bool IsBasmala)> _queue = [];
    private int _index;
    private int _session;

    public bool IsPlaying { get; private set; }
    public bool IsPaused { get; private set; }
    public int CurrentSurah { get; private set; }
    public int CurrentAyah { get; private set; }
    /// <summary>When the queue ends, the caller may continue (e.g. next surah).</summary>
    public Func<int, (int Surah, int From, int To)?>? OnFinished { get; set; }

    public event Action<int, int>? AyahStarted;      // surah, ayah (0 while the basmala plays)
    public event Action? StateChanged;
    public event Action<string>? Error;

    public QuranAudioService(Dispatcher dispatcher, IAppLog log, Func<string> reciter)
    {
        Http.DefaultRequestHeaders.UserAgent.ParseAdd("Mawaqeety (Windows desktop)");
        _dispatcher = dispatcher;
        _log = log;
        _reciter = reciter;
        _media = new MediaSession(dispatcher, log);
        _media.Ended += () => { if (IsPlaying) { _index++; _ = PlayCurrentAsync(_session); } };
        _media.Failed += msg => { if (IsPlaying) { _index++; _ = PlayCurrentAsync(_session); } };
        _media.ButtonPressed += b =>
        {
            if (!IsPlaying) return;
            switch (b)
            {
                case Windows.Media.SystemMediaTransportControlsButton.Play: if (IsPaused) TogglePause(); break;
                case Windows.Media.SystemMediaTransportControlsButton.Pause: if (!IsPaused) TogglePause(); break;
                case Windows.Media.SystemMediaTransportControlsButton.Stop: Stop(); break;
                case Windows.Media.SystemMediaTransportControlsButton.Next: Next(); break;
                case Windows.Media.SystemMediaTransportControlsButton.Previous: Previous(); break;
            }
        };
    }

    /// <summary>Next ayah (or, at the end, what <see cref="OnFinished"/> decides).</summary>
    public void Next()
    {
        if (!IsPlaying) return;
        _session++;
        _index++;
        IsPaused = false;
        _ = PlayCurrentAsync(_session);
    }

    /// <summary>Restarts the ayah, or goes to the previous one when it just started.</summary>
    public void Previous()
    {
        if (!IsPlaying) return;
        if (_media.Position > TimeSpan.FromSeconds(3) || _index == 0) { _media.Position = TimeSpan.Zero; return; }
        _session++;
        _index--;
        IsPaused = false;
        _ = PlayCurrentAsync(_session);
    }

    private static string CacheDir(string reciter) => Path.Combine(AppPaths.DataDir, "quran", reciter);

    public void Play(int surah, int fromAyah, int toAyah)
    {
        Stop();
        _session++;
        _queue = Reciters.Sequence(surah, fromAyah, toAyah).ToList();
        _index = 0;
        IsPlaying = true;
        IsPaused = false;
        StateChanged?.Invoke();
        _ = PlayCurrentAsync(_session);
    }

    private async Task PlayCurrentAsync(int session)
    {
        if (session != _session || _index >= _queue.Count) { Finish(session); return; }
        var (surah, ayah, basmala) = _queue[_index];
        var reciter = _reciter();
        var path = await EnsureAsync(reciter, surah, ayah);
        if (session != _session) return;
        if (path is null)
        {
            Error?.Invoke("تعذّر تحميل التلاوة. تأكد من الاتصال بالإنترنت (الآيات المحمّلة سابقًا تعمل دون إنترنت).");
            Stop();
            return;
        }
        if (_index + 1 < _queue.Count) _ = EnsureAsync(reciter, _queue[_index + 1].Surah, _queue[_index + 1].Ayah); // prefetch

        await _dispatcher.InvokeAsync(() =>
        {
            if (session != _session) return;
            _media.Open(path);
            var shownSurah = basmala ? _queue.Last().Surah : surah;
            CurrentSurah = shownSurah;
            CurrentAyah = basmala ? 0 : ayah;
            var name = QuranRepository.Default[shownSurah].Name;
            _media.SetInfo($"سورة {name} • {(basmala ? "البسملة" : "الآية " + QuranRepository.ArabicDigits(ayah))}",
                Reciters.Find(reciter).Name, "القرآن الكريم – سبيل");
            if (IsPaused) { IsPaused = false; StateChanged?.Invoke(); }
            AyahStarted?.Invoke(shownSurah, CurrentAyah);
        });
    }

    private void Finish(int session)
    {
        if (session != _session) return;
        var last = _queue.LastOrDefault();
        var next = OnFinished?.Invoke(last.Surah);
        if (next is { } n) { Play(n.Surah, n.From, n.To); return; }
        _dispatcher.BeginInvoke(Stop);
    }

    public async Task<string?> EnsureAsync(string reciter, int surah, int ayah)
    {
        var dir = CacheDir(reciter);
        var path = Path.Combine(dir, Reciters.FileName(surah, ayah));
        if (File.Exists(path)) return path;
        try
        {
            Directory.CreateDirectory(dir);
            var bytes = await Http.GetByteArrayAsync(Reciters.Url(reciter, surah, ayah));
            if (bytes.Length < 1000) return null;
            var tmp = path + ".part";
            await File.WriteAllBytesAsync(tmp, bytes);
            File.Move(tmp, path, overwrite: true);
            return path;
        }
        catch (Exception ex)
        {
            _log.Warn($"Recitation download failed {reciter} {surah}:{ayah}", ex);
            return null;
        }
    }

    public void TogglePause()
    {
        if (!IsPlaying) return;
        if (IsPaused) { _media.Resume(); IsPaused = false; }
        else { _media.Pause(); IsPaused = true; }
        StateChanged?.Invoke();
    }

    public void Pause()
    {
        if (!IsPlaying || IsPaused) return;
        _dispatcher.BeginInvoke(() => { _media.Pause(); IsPaused = true; StateChanged?.Invoke(); });
    }

    public void Stop()
    {
        if (!_dispatcher.CheckAccess()) { _dispatcher.BeginInvoke(Stop); return; }
        _session++;
        _media.Stop();
        var was = IsPlaying;
        IsPlaying = false;
        IsPaused = false;
        CurrentAyah = 0;
        if (was) StateChanged?.Invoke();
    }
}
