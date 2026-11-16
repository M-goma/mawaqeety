namespace Mawaqeety.Core;

/// <summary>Resolves IANA or Windows time-zone ids. DST is handled by TimeZoneInfo's adjustment rules.</summary>
public static class TimeZoneResolver
{
    public static TimeZoneInfo Resolve(string? id)
    {
        if (string.IsNullOrWhiteSpace(id)) return TimeZoneInfo.Local;
        if (id.StartsWith("UTC", StringComparison.OrdinalIgnoreCase) && TryParseFixed(id, out var fixedZone))
            return fixedZone;
        try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
        catch (Exception) { }
        if (TimeZoneInfo.TryConvertIanaIdToWindowsId(id, out var win))
            try { return TimeZoneInfo.FindSystemTimeZoneById(win); } catch (Exception) { }
        if (TimeZoneInfo.TryConvertWindowsIdToIanaId(id, out var iana))
            try { return TimeZoneInfo.FindSystemTimeZoneById(iana); } catch (Exception) { }
        return TimeZoneInfo.Local;
    }

    /// <summary>Parses "UTC+03:00" / "UTC-5" style ids into a fixed-offset zone (no DST).</summary>
    public static bool TryParseFixed(string id, out TimeZoneInfo zone)
    {
        zone = TimeZoneInfo.Utc;
        var rest = id[3..].Trim();
        if (rest.Length == 0) return true;
        var sign = rest[0] == '-' ? -1 : 1;
        rest = rest.TrimStart('+', '-');
        var parts = rest.Split(':');
        if (!int.TryParse(parts[0], out var h)) return false;
        var min = parts.Length > 1 && int.TryParse(parts[1], out var mm) ? mm : 0;
        var offset = new TimeSpan(sign * h, sign * min, 0);
        if (offset > TimeSpan.FromHours(14) || offset < TimeSpan.FromHours(-12)) return false;
        zone = TimeZoneInfo.CreateCustomTimeZone(id, offset, id, id);
        return true;
    }

    public static string FixedId(TimeSpan offset) =>
        $"UTC{(offset < TimeSpan.Zero ? "-" : "+")}{Math.Abs(offset.Hours):00}:{Math.Abs(offset.Minutes):00}";
}
