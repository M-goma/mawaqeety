using System.Windows.Threading;
using Mawaqeety.Core.Services;
using Windows.Media;

namespace Mawaqeety.App.Services;

/// <summary>
/// Live stream of إذاعة القرآن الكريم من القاهرة (the only station, by design): Windows media controls,
/// automatic reconnection, and a sleep timer.
/// </summary>
public sealed class RadioService
{
    public const string Name = "إذاعة القرآن الكريم";
    public const string City = "من القاهرة";
    private static readonly string[] Streams =
    [
        "https://stream.radiojar.com/8s5u5tpdtwzuv",
        "https://n0a.radiojar.com/8s5u5tpdtwzuv",
    ];

    private readonly Dispatcher _dispatcher;
    private readonly MediaSession _media;
    private readonly DispatcherTimer _retry;
    private readonly DispatcherTimer _sleep;
    private int _attempt;

    public bool IsOn { get; private set; }
    public string? Error { get; private set; }
    public DateTime? SleepAt { get; private set; }
    public int SleepMinutes { get; private set; }

    public event Action? Changed;
    /// <summary>Raised just before the radio starts (to stop anything else that is playing).</summary>
    public event Action? Starting;

    public RadioService(Dispatcher dispatcher, IAppLog log)
    {
        _dispatcher = dispatcher;
        _media = new MediaSession(dispatcher, log);
        _retry = new DispatcherTimer(DispatcherPriority.Background, dispatcher);
        _retry.Tick += (_, _) => { _retry.Stop(); if (IsOn) Connect(); };
        _sleep = new DispatcherTimer(DispatcherPriority.Background, dispatcher);
        _sleep.Tick += (_, _) => Stop();
        // A live stream never ends on its own: if it does, the connection dropped.
        _media.Ended += Reconnect;
        _media.Failed += _ => Reconnect();
        _media.ButtonPressed += b =>
        {
            if (b is SystemMediaTransportControlsButton.Pause or SystemMediaTransportControlsButton.Stop) Stop();
            else if (b == SystemMediaTransportControlsButton.Play && !IsOn) Play();
        };
    }

    public void Toggle() { if (IsOn) Stop(); else Play(); }

    public void Play()
    {
        Starting?.Invoke();
        IsOn = true;
        Error = null;
        _attempt = 0;
        Connect();
    }

    private void Connect()
    {
        _media.SetInfo(Name, $"{City} • بث مباشر", "الإذاعة", canSkip: false);
        _media.Open(Streams[_attempt % Streams.Length]);
        Changed?.Invoke();
    }

    private void Reconnect()
    {
        if (!IsOn) return;
        _attempt++;
        if (_attempt > 12)
        {
            Stop();
            Error = "تعذّر الاتصال بالإذاعة. تأكد من الإنترنت ثم حاول مرة أخرى.";
            Changed?.Invoke();
            return;
        }
        Error = "انقطع الاتصال… جارٍ إعادة الاتصال";
        _retry.Interval = TimeSpan.FromSeconds(_attempt < 3 ? 2 : 6);
        _retry.Start();
        Changed?.Invoke();
    }

    public void Stop()
    {
        if (!IsOn && SleepAt is null) return;
        IsOn = false;
        Error = null;
        _retry.Stop();
        _sleep.Stop();
        SleepAt = null;
        SleepMinutes = 0;
        _media.Stop();
        Changed?.Invoke();
    }

    /// <summary>Stops after <paramref name="minutes"/> (0 = no timer).</summary>
    public void SetSleep(int minutes)
    {
        _sleep.Stop();
        SleepMinutes = Math.Max(0, minutes);
        SleepAt = minutes > 0 ? DateTime.Now.AddMinutes(minutes) : null;
        if (minutes > 0) { _sleep.Interval = TimeSpan.FromMinutes(minutes); _sleep.Start(); }
        Changed?.Invoke();
    }
}
