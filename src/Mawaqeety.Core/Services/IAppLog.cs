namespace Mawaqeety.Core.Services;

/// <summary>Minimal logging abstraction so Core stays free of logging-framework dependencies.</summary>
public interface IAppLog
{
    void Info(string message);
    void Warn(string message, Exception? ex = null);
    void Error(string message, Exception? ex = null);
}

public sealed class NullLog : IAppLog
{
    public static readonly NullLog Instance = new();
    public void Info(string message) { }
    public void Warn(string message, Exception? ex = null) { }
    public void Error(string message, Exception? ex = null) { }
}
