using Mawaqeety.Core.Services;
using Serilog;
using Serilog.Core;

namespace Mawaqeety.App.Services;

/// <summary>Rolling daily log files in %AppData%\Mawaqeety\logs (14 days kept, 5 MB max each).</summary>
public sealed class FileLog : IAppLog, IDisposable
{
    private readonly Logger _logger;

    public FileLog(string dir)
    {
        _logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.File(Path.Combine(dir, "mawaqeety-.log"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 14,
                fileSizeLimitBytes: 5 * 1024 * 1024,
                rollOnFileSizeLimit: true,
                shared: false,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
            .CreateLogger();
    }

    public void Info(string message) => _logger.Information(message);
    public void Warn(string message, Exception? ex = null) => _logger.Warning(ex, message);
    public void Error(string message, Exception? ex = null) => _logger.Error(ex, message);
    public void Dispose() => _logger.Dispose();
}
