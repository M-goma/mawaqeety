using System.Windows.Threading;
using Mawaqeety.Core.Audio;
using Mawaqeety.Core.Scheduling;

namespace Mawaqeety.App.Services;

/// <summary>Bridges the background scheduler to toast + sound (adhan / custom / chime) on the UI thread.</summary>
public sealed class AlertSink(Dispatcher dispatcher, ToastService toast, SoundService sound, SettingsStore settings, AdhanLibrary adhan) : IAlertSink
{
    public void Deliver(PlannedAlert alert, bool playSound, bool showNotification)
    {
        dispatcher.BeginInvoke(() =>
        {
            var s = settings.Current;
            if (showNotification) toast.ShowAlert(alert, withStopButton: playSound, s.Use24HourClock);
            if (playSound) sound.Play(adhan.PathToPlay(AlertSoundResolver.Resolve(alert, s)), s.Volume);
        });
    }
}
