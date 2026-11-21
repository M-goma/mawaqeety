using System.Collections.Concurrent;
using System.Net.Http;
using Mawaqeety.Core.Audio;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>
/// Downloads adhan recordings on demand into %AppData%\Mawaqeety\adhan and serves them offline afterwards.
/// Downloads are atomic (temp file + move) and validated as MP3 so a broken file is never played.
/// </summary>
public sealed class AdhanLibrary(IAppLog log)
{
    // Own client: the shared API client has a 15 s timeout, too short for multi-MB audio on slow links.
    private static readonly HttpClient Http = CreateClient();

    private static HttpClient CreateClient()
    {
        var c = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd("Mawaqeety (Windows desktop prayer times)");
        return c;
    }

    private readonly ConcurrentDictionary<string, Task<bool>> _inFlight = new();
    private static readonly string Dir = Path.Combine(AppPaths.DataDir, "adhan");

    public event Action<string>? Downloaded;

    public string LocalPath(AdhanVoice v) => Path.Combine(Dir, v.Id + ".mp3");

    public bool IsAvailable(AdhanVoice v) => File.Exists(LocalPath(v));

    /// <summary>Returns true when the file is (now) available locally. Concurrent calls share one download.</summary>
    public Task<bool> EnsureAsync(AdhanVoice v)
    {
        if (IsAvailable(v)) return Task.FromResult(true);
        return _inFlight.GetOrAdd(v.Id, _ => DownloadAsync(v).ContinueWith(t =>
        {
            _inFlight.TryRemove(v.Id, out Task<bool>? _);
            return t.IsCompletedSuccessfully && t.Result;
        }, TaskScheduler.Default));
    }

    private async Task<bool> DownloadAsync(AdhanVoice v)
    {
        Directory.CreateDirectory(Dir);
        var target = LocalPath(v);
        var temp = target + ".part";
        try
        {
            // Adhan files are a few MB; allow more time than the default API timeout.
            using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(8));
            using var resp = await Http.GetAsync(v.Url, HttpCompletionOption.ResponseHeadersRead, cts.Token).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
            {
                log.Warn($"Adhan download HTTP {(int)resp.StatusCode}: {v.Id}");
                return false;
            }
            await using (var src = await resp.Content.ReadAsStreamAsync(cts.Token).ConfigureAwait(false))
            await using (var dst = File.Create(temp))
                await src.CopyToAsync(dst, cts.Token).ConfigureAwait(false);

            if (!LooksLikeMp3(temp))
            {
                log.Warn($"Adhan download is not a valid MP3: {v.Id}");
                File.Delete(temp);
                return false;
            }
            File.Move(temp, target, overwrite: true);
            log.Info($"Adhan downloaded: {v.Id} ({new FileInfo(target).Length / 1024} KB)");
            Downloaded?.Invoke(v.Id);
            return true;
        }
        catch (Exception ex)
        {
            log.Warn($"Adhan download failed (offline?): {v.Id}", ex);
            try { File.Delete(temp); } catch { }
            return false;
        }
    }

    private static bool LooksLikeMp3(string path)
    {
        var info = new FileInfo(path);
        if (info.Length < 50 * 1024) return false;
        Span<byte> h = stackalloc byte[3];
        using var f = File.OpenRead(path);
        if (f.Read(h) != 3) return false;
        return (h[0] == 'I' && h[1] == 'D' && h[2] == '3') || (h[0] == 0xFF && (h[1] & 0xE0) == 0xE0);
    }

    /// <summary>
    /// Resolves the file to play now. If the adhan is not downloaded yet, starts the download in the
    /// background and returns null (the caller plays the default chime this time).
    /// </summary>
    public string? PathToPlay(AlertSound sound)
    {
        if (sound.CustomPath is { } custom) return custom;
        if (sound.Adhan is not { } v) return null;
        if (IsAvailable(v)) return LocalPath(v);
        _ = EnsureAsync(v);
        return null;
    }
}
