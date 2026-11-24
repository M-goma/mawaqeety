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

    public static bool HasArabicVoice => ArabicVoice() is not null;

    private static VoiceInformation? ArabicVoice()
    {
        try
        {
            return SpeechSynthesizer.AllVoices
                .Where(v => v.Language.StartsWith("ar", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(v => v.Language.Equals("ar-EG", StringComparison.OrdinalIgnoreCase))
                .ThenByDescending(v => v.Gender == VoiceGender.Male)
                .FirstOrDefault();
        }
        catch { return null; }
    }

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
            using var synth = new SpeechSynthesizer { Voice = ArabicVoice() };
            synth.Options.SpeakingRate = 0.92;
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
