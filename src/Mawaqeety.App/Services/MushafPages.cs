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

    /// <summary>The page image from the device, or from the internet (then saved). Null when offline and not saved.</summary>
    public Task<byte[]?> LoadAsync(int page)
    {
        var f = FileOf(page);
        if (File.Exists(f))
        {
            try { return Task.FromResult<byte[]?>(File.ReadAllBytes(f)); }
            catch (Exception ex) { log.Warn($"Reading Mushaf page {page} failed", ex); }
        }
        return _pending.GetOrAdd(page, p => FetchAsync(p).ContinueWith(t =>
        {
            _pending.TryRemove(p, out _);
            return t.IsCompletedSuccessfully ? t.Result : null;
        }));
    }

    private async Task<byte[]?> FetchAsync(int page)
    {
        for (var attempt = 0; attempt < 3; attempt++)
        {
            try
            {
                var bytes = await Http.GetByteArrayAsync(MushafIndex.Default.Url(page));
                if (bytes.Length > 1000)
                {
                    Directory.CreateDirectory(Dir);
                    var tmp = FileOf(page) + ".part";
                    await File.WriteAllBytesAsync(tmp, bytes);
                    File.Move(tmp, FileOf(page), overwrite: true);
                    return bytes;
                }
            }
            catch (Exception ex) when (attempt == 2) { log.Warn($"Mushaf page {page} download failed", ex); }
            catch { /* retry */ }
            await Task.Delay(TimeSpan.FromSeconds(1 + attempt * 2));
        }
        return null;
    }

    public void DeleteAll()
    {
        try { if (Directory.Exists(Dir)) Directory.Delete(Dir, recursive: true); }
        catch (Exception ex) { log.Warn("Deleting Mushaf pages failed", ex); }
    }
}
