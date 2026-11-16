namespace Mawaqeety.App.Services;

/// <summary>Prevents multiple copies. A second launch signals the first one to bring its window to front.</summary>
public sealed class SingleInstance : IDisposable
{
    private readonly Mutex _mutex;
    private readonly EventWaitHandle _showEvent;
    private RegisteredWaitHandle? _registration;

    public bool IsFirst { get; }

    public SingleInstance(string id)
    {
        var scope = $"Local\\{id}.{Environment.UserName}";
        _mutex = new Mutex(initiallyOwned: true, scope + ".mutex", out var createdNew);
        IsFirst = createdNew;
        _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, scope + ".show");
    }

    public void SignalFirstInstance() => _showEvent.Set();

    /// <summary>Invokes the callback (on a thread-pool thread) whenever another instance asks to be shown.</summary>
    public void ListenForActivation(Action onActivate) =>
        _registration = ThreadPool.RegisterWaitForSingleObject(_showEvent, (_, _) => onActivate(), null, Timeout.Infinite, executeOnlyOnce: false);

    public void Dispose()
    {
        _registration?.Unregister(null);
        if (IsFirst)
        {
            try { _mutex.ReleaseMutex(); } catch (ApplicationException) { }
        }
        _mutex.Dispose();
        _showEvent.Dispose();
    }
}
