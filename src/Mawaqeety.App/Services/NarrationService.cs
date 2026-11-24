using System.Windows.Media;
using System.Windows.Threading;
using Mawaqeety.Core.Services;
using Windows.Media.SpeechSynthesis;

namespace Mawaqeety.App.Services;

/// <summary>
/// Reads the prophets' stories aloud with the Arabic text-to-speech voice built into Windows
/// (works offline). Requires an Arabic speech voice (Settings → Time &amp; language → Speech).
/// </summary>
public sealed class NarrationService(Dispatcher dispatcher, IAppLog log)
{
    private MediaPlayer? _player;
    private List<string> _chunks = [];
    private int _index;
    private int _session;

    public bool IsSpeaking { get; private set; }
    public event Action? StateChanged;
    public event Action<int>? ChunkStarted;

    /// <summary>"Male" or "Female" (read on every chunk so a change applies immediately).</summary>
    public Func<string> PreferredGender { get; set; } = () => "Male";

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

    private VoiceInformation? ArabicVoice() => Pick().Voice;

    /// <returns>false when no Arabic voice is installed.</returns>
    public bool Speak(IReadOnlyList<string> chunks)
    {
        Stop();
        if (ArabicVoice() is null) return false;
        _session++;
        _chunks = chunks.Where(c => !string.IsNullOrWhiteSpace(c)).ToList();
        _index = 0;
        IsSpeaking = true;
        StateChanged?.Invoke();
        _ = SpeakCurrentAsync(_session);
        return true;
    }

    private async Task SpeakCurrentAsync(int session)
    {
        if (session != _session) return;
        if (_index >= _chunks.Count) { await dispatcher.InvokeAsync(Stop); return; }
        try
        {
            var (voice, exact) = Pick();
            using var synth = new SpeechSynthesizer { Voice = voice };
            synth.Options.SpeakingRate = 0.92;
            // Only one Arabic voice installed: approximate the other gender by changing the pitch.
            if (!exact) synth.Options.AudioPitch = PreferredGender() == "Female" ? 1.35 : 0.75;
            using var stream = await synth.SynthesizeTextToStreamAsync(_chunks[_index]);
            var dir = Path.Combine(Path.GetTempPath(), "Mawaqeety");
            Directory.CreateDirectory(dir);
            var file = Path.Combine(dir, $"story-{session}-{_index}.wav");
            await using (var fs = File.Create(file))
                await stream.AsStreamForRead().CopyToAsync(fs);
            if (session != _session) return;
            var idx = _index;
            await dispatcher.InvokeAsync(() =>
            {
                _player?.Close();
                var p = new MediaPlayer();
                p.MediaEnded += (_, _) => { _index++; _ = SpeakCurrentAsync(session); };
                p.Open(new Uri(file));
                p.Play();
                _player = p;
                ChunkStarted?.Invoke(idx);
            });
        }
        catch (Exception ex)
        {
            log.Warn("Narration failed", ex);
            await dispatcher.InvokeAsync(Stop);
        }
    }

    public void Stop()
    {
        if (!dispatcher.CheckAccess()) { dispatcher.BeginInvoke(Stop); return; }
        _session++;
        _player?.Stop();
        _player?.Close();
        _player = null;
        var was = IsSpeaking;
        IsSpeaking = false;
        if (was) StateChanged?.Invoke();
    }
}
