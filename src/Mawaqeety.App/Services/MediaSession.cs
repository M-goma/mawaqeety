using System.Windows.Threading;
using Mawaqeety.Core.Services;
using Windows.Media;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage.Streams;
using WinMediaPlayer = Windows.Media.Playback.MediaPlayer;

namespace Mawaqeety.App.Services;

/// <summary>
/// One audio player connected to Windows' media controls (the media overlay next to the volume flyout, the lock screen,
/// and the play/pause/next/previous keys of keyboards and headsets). All events are raised on the UI thread.
/// </summary>
public sealed class MediaSession
{
    private readonly Dispatcher _dispatcher;
    private readonly IAppLog _log;
    private WinMediaPlayer? _player;
    private SystemMediaTransportControls? _smtc;
    private long _openId;

    public event Action? Ended;
    public event Action<string>? Failed;
    /// <summary>A media key or a button in Windows' media overlay was pressed.</summary>
    public event Action<SystemMediaTransportControlsButton>? ButtonPressed;

    public MediaSession(Dispatcher dispatcher, IAppLog log)
    {
        _dispatcher = dispatcher;
        _log = log;
    }

    private WinMediaPlayer Player
    {
        get
        {
            if (_player is not null) return _player;
            var p = new WinMediaPlayer { AutoPlay = false, AudioCategory = MediaPlayerAudioCategory.Media };
            p.CommandManager.IsEnabled = false; // we drive the media controls ourselves
            p.MediaEnded += (_, _) =>
            {
                var id = Interlocked.Read(ref _openId);
                _dispatcher.BeginInvoke(() => { if (id == Interlocked.Read(ref _openId)) Ended?.Invoke(); });
            };
            p.MediaFailed += (_, e) =>
            {
                var id = Interlocked.Read(ref _openId);
                _log.Warn($"Playback failed: {e.Error} {e.ErrorMessage}", e.ExtendedErrorCode);
                _dispatcher.BeginInvoke(() => { if (id == Interlocked.Read(ref _openId)) Failed?.Invoke(e.ErrorMessage); });
            };
            var smtc = p.SystemMediaTransportControls;
            smtc.IsPlayEnabled = smtc.IsPauseEnabled = smtc.IsStopEnabled = true;
            smtc.IsNextEnabled = smtc.IsPreviousEnabled = true;
            smtc.ButtonPressed += (_, e) => _dispatcher.BeginInvoke(() => ButtonPressed?.Invoke(e.Button));
            _smtc = smtc;
            _player = p;
            return p;
        }
    }

    /// <summary>Plays a local file path or an http(s) URL.</summary>
    public void Open(string pathOrUrl)
    {
        try
        {
            var p = Player;
            Interlocked.Increment(ref _openId);
            var uri = pathOrUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase) ? new Uri(pathOrUrl) : new Uri(Path.GetFullPath(pathOrUrl));
            p.Source = MediaSource.CreateFromUri(uri);
            p.Play();
            SetStatus(MediaPlaybackStatus.Playing);
        }
        catch (Exception ex)
        {
            _log.Warn("Opening audio failed", ex);
            Failed?.Invoke(ex.Message);
        }
    }

    public void Resume()
    {
        _player?.Play();
        SetStatus(MediaPlaybackStatus.Playing);
    }

    public void Pause()
    {
        _player?.Pause();
        SetStatus(MediaPlaybackStatus.Paused);
    }

    /// <summary>Stops playback and removes the entry from Windows' media controls.</summary>
    public void Stop()
    {
        Interlocked.Increment(ref _openId);
        if (_player is null) return;
        try
        {
            _player.Pause();
            _player.Source = null;
            if (_smtc is not null)
            {
                _smtc.PlaybackStatus = MediaPlaybackStatus.Closed;
                _smtc.DisplayUpdater.ClearAll();
                _smtc.DisplayUpdater.Update();
                _smtc.IsEnabled = false;
            }
        }
        catch (Exception ex) { _log.Warn("Stopping audio failed", ex); }
    }

    public TimeSpan Position
    {
        get => _player?.PlaybackSession.Position ?? TimeSpan.Zero;
        set { if (_player is not null) _player.PlaybackSession.Position = value < TimeSpan.Zero ? TimeSpan.Zero : value; }
    }

    public void Seek(TimeSpan delta) => Position = Position + delta;

    public void SetStatus(MediaPlaybackStatus status)
    {
        if (_smtc is null) return;
        try
        {
            _smtc.IsEnabled = true;
            _smtc.PlaybackStatus = status;
        }
        catch { /* media controls are optional */ }
    }

    /// <summary>What Windows shows in its media overlay.</summary>
    public void SetInfo(string title, string artist, string album, bool canSkip = true)
    {
        if (_smtc is null) _ = Player;
        try
        {
            _smtc!.IsEnabled = true;
            _smtc.IsNextEnabled = _smtc.IsPreviousEnabled = canSkip;
            var u = _smtc.DisplayUpdater;
            u.Type = MediaPlaybackType.Music;
            u.MusicProperties.Title = title;
            u.MusicProperties.Artist = artist;
            u.MusicProperties.AlbumTitle = album;
            if (File.Exists(AppPaths.LogoPng))
                u.Thumbnail = RandomAccessStreamReference.CreateFromUri(new Uri(AppPaths.LogoPng));
            u.Update();
        }
        catch (Exception ex) { _log.Warn("Media controls update failed", ex); }
    }
}
