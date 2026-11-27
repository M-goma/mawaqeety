using System.Net.Http;
using System.Windows.Threading;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Services;
using Windows.Media;
using Windows.Media.SpeechSynthesis;

namespace Mawaqeety.App.Services;

/// <summary>
/// Reads the prophets' stories aloud: the recorded narrations ("Nabil" for the male voice, "Areen" for the female voice),
/// kept in %AppData%\Mawaqeety\stories\ after the first listen so they work offline. When a story has no recording,
/// the Arabic text-to-speech voice built into Windows is used instead.
/// </summary>
public sealed class NarrationService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(5) };
    private readonly Dispatcher _dispatcher;
    private readonly IAppLog _log;
    private readonly MediaSession _media;
    private List<Func<Task<string?>>> _parts = [];
    private int _index;
    private int _session;
    private string _title = "", _artist = "";

    public bool IsSpeaking { get; private set; }
    public bool IsPaused { get; private set; }
    /// <summary>The story being read (prophet id), or null.</summary>
    public string? CurrentId { get; private set; }
    public event Action? StateChanged;
    public event Action<int>? ChunkStarted;
    /// <summary>A story reached its end by itself (not stopped by the user).</summary>
    public event Action<string>? Finished;
    /// <summary>The next/previous key of the keyboard or Windows' media overlay asks for another story.</summary>
    public event Action<int>? SkipRequested;

    /// <summary>"Male" or "Female" (read on every chunk so a change applies immediately).</summary>
    public Func<string> PreferredGender { get; set; } = () => "Male";

    public static string VoiceName(string gender) => gender == "Female" ? "عرين" : "نبيل";

    public NarrationService(Dispatcher dispatcher, IAppLog log)
    {
        _dispatcher = dispatcher;
        _log = log;
        _media = new MediaSession(dispatcher, log);
        _media.Ended += () => { if (IsSpeaking) { _index++; _ = PlayCurrentAsync(_session); } };
        _media.Failed += msg =>
        {
            if (!IsSpeaking) return;
            _log.Warn($"Story part failed: {msg}");
            _index++;
            _ = PlayCurrentAsync(_session);
        };
        _media.ButtonPressed += b =>
        {
            if (!IsSpeaking) return;
            switch (b)
            {
                case SystemMediaTransportControlsButton.Play: if (IsPaused) TogglePause(); break;
                case SystemMediaTransportControlsButton.Pause: if (!IsPaused) TogglePause(); break;
                case SystemMediaTransportControlsButton.Stop: Stop(); break;
                case SystemMediaTransportControlsButton.Next: SkipRequested?.Invoke(1); break;
                case SystemMediaTransportControlsButton.Previous: SkipRequested?.Invoke(-1); break;
            }
        };
    }

    // ---------------- Windows voice (fallback) ----------------
    /// <summary>True when the exact gender requested is installed (otherwise the pitch is adjusted).</summary>
    public bool ExactGenderAvailable => Pick().Exact;

    private (VoiceInformation? Voice, bool Exact) Pick()
    {
        try
        {
            var ar = SpeechSynthesizer.AllVoices
                .Where(v => v.Language.StartsWith("ar", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(v => v.Language.Equals("ar-EG", StringComparison.OrdinalIgnoreCase))
                .ToList();
            var want = PreferredGender() == "Female" ? VoiceGender.Female : VoiceGender.Male;
            var exact = ar.FirstOrDefault(v => v.Gender == want);
            return exact is not null ? (exact, true) : (ar.FirstOrDefault(), false);
        }
        catch { return (null, false); }
    }

    public bool HasRecording(string prophetId) => StoryAudio.Default.Parts(prophetId, PreferredGender()).Count > 0;

    /// <summary>Starts a story. Returns false when there is no recording and no Arabic Windows voice.</summary>
    public bool Play(string prophetId, string title, IReadOnlyList<string> ttsChunks)
    {
        Stop();
        var gender = PreferredGender();
        var files = StoryAudio.Default.Parts(prophetId, gender);
        List<Func<Task<string?>>> parts;
        if (files.Count > 0)
        {
            parts = files.Select(f => (Func<Task<string?>>)(() => Task.FromResult<string?>(RecordingSource(f)))).ToList();
            _artist = $"بصوت {VoiceName(gender)}";
        }
        else
        {
            if (Pick().Voice is null) return false;
            var chunks = ttsChunks.Where(c => !string.IsNullOrWhiteSpace(c)).ToList();
            var session = _session + 1;
            parts = chunks.Select((c, i) => (Func<Task<string?>>)(() => SynthesizeAsync(c, session, i))).ToList();
            _artist = "صوت Windows";
        }
        _session++;
        _parts = parts;
        _index = 0;
        _title = title;
        CurrentId = prophetId;
        IsSpeaking = true;
        IsPaused = false;
        StateChanged?.Invoke();
        _ = PlayCurrentAsync(_session);
        return true;
    }

    private static string CacheDir => Path.Combine(AppPaths.DataDir, "stories");

    /// <summary>The saved copy, or the online file (a copy is then saved in the background).</summary>
    private string RecordingSource(string file)
    {
        var local = Path.Combine(CacheDir, file);
        if (File.Exists(local)) return local;
        _ = CacheAsync(file, local);
        return StoryAudio.Default.BaseUrl + file;
    }

    private async Task CacheAsync(string file, string local)
    {
        try
        {
            Directory.CreateDirectory(CacheDir);
            var bytes = await Http.GetByteArrayAsync(StoryAudio.Default.BaseUrl + file);
            if (bytes.Length < 10_000) return;
            var tmp = local + ".part";
            await File.WriteAllBytesAsync(tmp, bytes);
            File.Move(tmp, local, overwrite: true);
        }
        catch (Exception ex) { _log.Warn($"Saving story audio failed ({file})", ex); }
    }

    private async Task<string?> SynthesizeAsync(string text, int session, int index)
    {
        var (voice, exact) = Pick();
        using var synth = new SpeechSynthesizer { Voice = voice };
        synth.Options.SpeakingRate = 0.92;
        // Only one Arabic voice installed: approximate the other gender by changing the pitch.
        if (!exact) synth.Options.AudioPitch = PreferredGender() == "Female" ? 1.35 : 0.75;
        using var stream = await synth.SynthesizeTextToStreamAsync(text);
        var dir = Path.Combine(Path.GetTempPath(), "Mawaqeety");
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, $"story-{session}-{index}.wav");
        await using (var fs = File.Create(file))
            await stream.AsStreamForRead().CopyToAsync(fs);
        return file;
    }

    private async Task PlayCurrentAsync(int session)
    {
        if (session != _session) return;
        if (_index >= _parts.Count)
        {
            var id = CurrentId;
            await _dispatcher.InvokeAsync(Stop);
            if (id is not null) Finished?.Invoke(id);
            return;
        }
        try
        {
            var src = await _parts[_index]();
            if (session != _session) return;
            if (src is null) { _index++; await PlayCurrentAsync(session); return; }
            var idx = _index;
            await _dispatcher.InvokeAsync(() =>
            {
                if (session != _session) return;
                _media.Open(src);
                _media.SetInfo(_title, _artist, "قصص الأنبياء – سبيل");
                ChunkStarted?.Invoke(idx);
            });
        }
        catch (Exception ex)
        {
            _log.Warn("Narration failed", ex);
            await _dispatcher.InvokeAsync(Stop);
        }
    }

    public void TogglePause()
    {
        if (!IsSpeaking) return;
        if (IsPaused) _media.Resume(); else _media.Pause();
        IsPaused = !IsPaused;
        StateChanged?.Invoke();
    }

    /// <summary>Moves 15 seconds back or forward in the recording.</summary>
    public void Seek(int seconds) { if (IsSpeaking) _media.Seek(TimeSpan.FromSeconds(seconds)); }

    public void Stop()
    {
        if (!_dispatcher.CheckAccess()) { _dispatcher.BeginInvoke(Stop); return; }
        _session++;
        _media.Stop();
        var was = IsSpeaking;
        IsSpeaking = false;
        IsPaused = false;
        CurrentId = null;
        if (was) StateChanged?.Invoke();
    }
}
