using System.Windows.Media;
using System.Windows.Threading;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>Plays MP3/WAV alerts with WPF's MediaPlayer (no extra codecs needed on Windows 10/11).</summary>
public sealed class SoundService(Dispatcher dispatcher, IAppLog log)
{
    private MediaPlayer? _player;

    public event Action<bool>? PlayingChanged;
    public bool IsPlaying { get; private set; }

    public void Play(string? path, double volume)
    {
        dispatcher.BeginInvoke(() =>
        {
            Stop();
            var file = !string.IsNullOrWhiteSpace(path) && File.Exists(path) ? path : AppPaths.DefaultSound;
            if (!string.IsNullOrWhiteSpace(path) && file != path)
                log.Warn($"Sound file not found, using default chime: {path}");
            try
            {
                var p = new MediaPlayer { Volume = Math.Clamp(volume, 0, 1) };
                p.MediaEnded += (_, _) => Stop();
                p.MediaFailed += (_, e) =>
                {
                    log.Warn($"Cannot play sound {file}", e.ErrorException);
                    Stop();
                    if (file != AppPaths.DefaultSound) Play(null, volume);
                };
                p.Open(new Uri(file, UriKind.Absolute));
                p.Play();
                _player = p;
                SetPlaying(true);
            }
            catch (Exception ex) { log.Error("Sound playback failed", ex); }
        });
    }

    public void Stop()
    {
        if (!dispatcher.CheckAccess()) { dispatcher.BeginInvoke(Stop); return; }
        if (_player is null) return;
        _player.Stop();
        _player.Close();
        _player = null;
        SetPlaying(false);
    }

    private void SetPlaying(bool v)
    {
        if (IsPlaying == v) return;
        IsPlaying = v;
        PlayingChanged?.Invoke(v);
    }
}
