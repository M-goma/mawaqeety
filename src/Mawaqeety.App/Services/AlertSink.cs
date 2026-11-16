using System.Windows.Threading;
using Mawaqeety.Core.Scheduling;

namespace Mawaqeety.App.Services;

/// <summary>Bridges the background scheduler to toast + sound on the UI thread.</summary>
public sealed class AlertSink(Dispatcher dispatcher, ToastService toast, SoundService sound, SettingsStore settings) : IAlertSink
{
    public void Deliver(PlannedAlert alert, bool playSound, bool showNotification)
    {
        dispatcher.BeginInvoke(() =>
        {
            var s = settings.Current;
            if (showNotification) toast.ShowAlert(alert, withStopButton: playSound, s.Use24HourClock);
            if (playSound) sound.Play(alert.SoundPath, s.Volume);
        });
    }
}
