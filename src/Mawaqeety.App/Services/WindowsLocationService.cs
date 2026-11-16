using Mawaqeety.Core.Geo;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Services;
using Windows.Devices.Geolocation;

namespace Mawaqeety.App.Services;

/// <summary>Automatic location: Windows Location API first (GPS/Wi-Fi), then IP-based fallback.</summary>
public sealed class WindowsLocationService(LocationSearchService search, IAppLog log)
{
    public async Task<GeoLocation?> DetectAsync(CancellationToken ct)
    {
        try
        {
            var access = await Geolocator.RequestAccessAsync().AsTask(ct);
            if (access == GeolocationAccessStatus.Allowed)
            {
                var locator = new Geolocator { DesiredAccuracy = PositionAccuracy.Default };
                var pos = await locator.GetGeopositionAsync(TimeSpan.FromMinutes(10), TimeSpan.FromSeconds(15)).AsTask(ct);
                var p = pos.Coordinate.Point.Position;
                log.Info("Location from Windows Location API");
                return await search.FromCoordinatesAsync(p.Latitude, p.Longitude, ct);
            }
            log.Warn($"Windows location access: {access}");
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { log.Warn("Windows location unavailable", ex); }

        var ip = await search.FromIpAsync(ct);
        if (ip is not null) log.Info("Location from IP address");
        return ip;
    }
}
