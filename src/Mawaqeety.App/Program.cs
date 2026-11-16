using Mawaqeety.App.Services;
using Velopack;

namespace Mawaqeety.App;

public static class Program
{
    public const string BackgroundArg = "--background";

    [STAThread]
    public static int Main(string[] args)
    {
        // Must run first: handles install/update/uninstall hooks from the Velopack installer.
        VelopackApp.Build()
            .OnBeforeUninstallFastCallback(_ =>
            {
                AutoStartService.Disable();
                ToastService.UninstallRegistration();
            })
            .OnFirstRun(_ => AutoStartService.Enable())
            .Run();

        using var instance = new SingleInstance("Mawaqeety.SingleInstance.7F3A2C1E");
        if (!instance.IsFirst)
        {
            // Another copy is running: ask it to show its window, then quit.
            instance.SignalFirstInstance();
            return 0;
        }

        var startInBackground = args.Contains(BackgroundArg, StringComparer.OrdinalIgnoreCase);
        var app = new App(instance, startInBackground);
        app.InitializeComponent();
        return app.Run();
    }
}
