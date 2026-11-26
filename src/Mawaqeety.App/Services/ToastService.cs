using CommunityToolkit.WinUI.Notifications;
using Mawaqeety.App.Localization;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Scheduling;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>Native Windows 10/11 toast notifications (Action Center) for an unpackaged desktop app.</summary>
public sealed class ToastService
{
    private readonly IAppLog _log;

    public event Action? OpenRequested;
    public event Action? StopSoundRequested;
    /// <summary>A "did you pray?" button: date, prayer, how it was prayed.</summary>
    public event Action<DateOnly, Prayer, Core.Tracking.PrayerLog>? PrayerLogged;

    public ToastService(IAppLog log)
    {
        _log = log;
        try
        {
            ToastNotificationManagerCompat.OnActivated += e =>
            {
                var args = ToastArguments.Parse(e.Argument);
                args.TryGetValue("action", out var action);
                if (action == "stopSound") StopSoundRequested?.Invoke();
                else if (action == "log")
                {
                    if (args.TryGetValue("d", out var d) && DateOnly.TryParse(d, out var date) &&
                        args.TryGetValue("p", out var p) && Enum.TryParse<Prayer>(p, out var prayer) &&
                        args.TryGetValue("v", out var v) && int.TryParse(v, out var n))
                        PrayerLogged?.Invoke(date, prayer, (Core.Tracking.PrayerLog)n);
                }
                else if (action != "dismiss") OpenRequested?.Invoke();
            };
        }
        catch (Exception ex) { _log.Error("Toast activation registration failed", ex); }
    }

    public void ShowAlert(PlannedAlert a, bool withStopButton, bool use24h)
    {
        var loc = Loc.I;
        var name = loc.Prayer(a.Prayer);
        var title = (a.Kind, a.Prayer) switch
        {
            (AlertKind.AtTime, Prayer.Sunrise) => loc["ToastAtTimeSunrise"],
            (AlertKind.AtTime, _) => string.Format(loc["ToastAtTime"], name),
            (AlertKind.PreAlert, Prayer.Sunrise) => string.Format(loc["ToastPreSunrise"], name, a.MinutesBefore),
            _ => string.Format(loc["ToastPre"], name, a.MinutesBefore),
        };
        var body = string.Format(loc["ToastBody"], name, loc.FormatTime(a.PrayerTime, use24h));
        Show(title, body, withStopButton, tag: $"{a.Prayer}-{a.Kind}", reminder: a.Kind == AlertKind.AtTime && a.Prayer != Prayer.Sunrise);
    }

    public void Show(string title, string body, bool withStopButton = false, string tag = "general", bool reminder = false)
    {
        try
        {
            var b = new ToastContentBuilder()
                .AddArgument("action", "open")
                .AddText(title, hintMaxLines: 2)
                .AddText(body)
                .AddAttributionText(Loc.T("AppName") + " • " + Loc.T("Slogan"))
                .AddAudio(new ToastAudio { Silent = true }); // the app plays its own (user-selected) sound

            if (File.Exists(AppPaths.LogoPng))
                b.AddAppLogoOverride(new Uri(AppPaths.LogoPng), ToastGenericAppLogoCrop.Default);

            if (withStopButton)
                b.AddButton(new ToastButton().SetContent(Loc.T("ToastStopSound")).AddArgument("action", "stopSound").SetBackgroundActivation());
            if (reminder)
            {
                b.SetToastScenario(ToastScenario.Reminder); // stays on screen until dismissed
                b.AddButton(new ToastButton().SetContent(Loc.T("ToastDismiss")).AddArgument("action", "dismiss").SetBackgroundActivation());
            }

            b.Show(t =>
            {
                t.Tag = tag;
                t.Group = "prayer";
                t.ExpirationTime = DateTimeOffset.Now.AddHours(2);
            });
        }
        catch (Exception ex) { _log.Error("Showing notification failed", ex); }
    }

    /// <summary>"Did you pray?" with buttons that log the prayer without opening the app.</summary>
    public void ShowPrayerCheck(DateOnly date, Prayer prayer, string name)
    {
        try
        {
            var b = new ToastContentBuilder()
                .AddArgument("action", "open")
                .AddText($"هل صليت {name}؟ 🤍")
                .AddText("سجّل صلاتك لتكتمل إحصائيتك اليوم.")
                .AddAttributionText(Loc.T("AppName"))
                .AddAudio(new ToastAudio { Silent = true });
            if (File.Exists(AppPaths.LogoPng)) b.AddAppLogoOverride(new Uri(AppPaths.LogoPng), ToastGenericAppLogoCrop.Default);
            foreach (var (label, v) in new[] { ("🕌 في المسجد", 1), ("👥 جماعة", 2), ("🧍 منفردًا", 3) })
                b.AddButton(new ToastButton().SetContent(label).AddArgument("action", "log").AddArgument("d", date.ToString("yyyy-MM-dd"))
                    .AddArgument("p", prayer.ToString()).AddArgument("v", v).SetBackgroundActivation());
            b.Show(t => { t.Tag = $"check-{prayer}"; t.Group = "check"; t.ExpirationTime = DateTimeOffset.Now.AddHours(3); });
        }
        catch (Exception ex) { _log.Error("Showing prayer check failed", ex); }
    }

    public static void UninstallRegistration()
    {
        try { ToastNotificationManagerCompat.Uninstall(); } catch { /* best effort during uninstall */ }
    }
}
