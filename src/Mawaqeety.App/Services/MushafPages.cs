using System.Collections.Concurrent;
using System.Net.Http;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.Services;

/// <summary>
/// Page images of the Madinah Mushaf: downloaded on first view and kept in %AppData%\Mawaqeety\mushaf\NNN.png
/// (about 66 MB for all 604 pages), so the Mushaf works offline afterwards.
/// </summary>
public sealed class MushafPages(IAppLog log)
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(40) };
    private readonly ConcurrentDictionary<int, Task<byte[]?>> _pending = new();

    public static string Dir => Path.Combine(AppPaths.DataDir, "mushaf");
    private static string FileOf(int page) => Path.Combine(Dir, $"{page:000}.png");

    public bool IsSaved(int page) => File.Exists(FileOf(page));

    public int SavedCount()
    {
        try { return Directory.Exists(Dir) ? Directory.EnumerateFiles(Dir, "*.png").Count() : 0; }
        catch { return 0; }
    }

    /// <summary>A copy of the pages on a CDN, used when GitHub refuses (it limits many requests in a row).</summary>
    private const string Mirror = "https://cdn.jsdelivr.net/gh/M-goma/mawaqeety@mushaf-pages/pages/";
    private DateTime _coolDownUntil = DateTime.MinValue;

    /// <summary>The page image from the device, or from the internet (then saved). Null when offline and not saved.</summary>
    public Task<byte[]?> LoadAsync(int page, bool bulk = false, CancellationToken ct = default)
    {
        var f = FileOf(page);
        if (File.Exists(f))
        {
            try { return Task.FromResult<byte[]?>(File.ReadAllBytes(f)); }
            catch (Exception ex) { log.Warn($"Reading Mushaf page {page} failed", ex); }
        }
        return _pending.GetOrAdd(page, p => FetchAsync(p, bulk ? 8 : 3, ct).ContinueWith(t =>
        {
            _pending.TryRemove(p, out _);
            return t.IsCompletedSuccessfully ? t.Result : null;
        }));
    }

    private async Task<byte[]?> FetchAsync(int page, int attempts, CancellationToken ct)
    {
        for (var attempt = 0; attempt < attempts; attempt++)
        {
            if (ct.IsCancellationRequested) return null;
            var wait = _coolDownUntil - DateTime.UtcNow;
            if (wait > TimeSpan.Zero) await Task.Delay(wait, CancellationToken.None);
            var delay = TimeSpan.FromSeconds(1 + attempt * 2);
            try
            {
                var url = attempt % 2 == 0 ? MushafIndex.Default.Url(page) : $"{Mirror}{page:000}.png";
                using var r = await Http.GetAsync(url, CancellationToken.None);
                if (r.IsSuccessStatusCode)
                {
                    var bytes = await r.Content.ReadAsByteArrayAsync(CancellationToken.None);
                    if (bytes.Length > 1000)
                    {
                        Directory.CreateDirectory(Dir);
                        var tmp = FileOf(page) + ".part";
                        await File.WriteAllBytesAsync(tmp, bytes, CancellationToken.None);
                        File.Move(tmp, FileOf(page), overwrite: true);
                        return bytes;
                    }
                }
                else if ((int)r.StatusCode == 429 || (int)r.StatusCode >= 500)
                {
                    // Too many requests: every download waits a little before the next one.
                    delay = r.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(Math.Clamp(5 * (attempt + 1), 5, 30));
                    _coolDownUntil = DateTime.UtcNow + delay;
                }
            }
            catch (Exception ex) when (attempt == attempts - 1) { log.Warn($"Mushaf page {page} download failed", ex); }
            catch { /* retry */ }
            await Task.Delay(delay, CancellationToken.None);
        }
        return null;
    }

    public void DeleteAll()
    {
        try { if (Directory.Exists(Dir)) Directory.Delete(Dir, recursive: true); }
        catch (Exception ex) { log.Warn("Deleting Mushaf pages failed", ex); }
    }
}
