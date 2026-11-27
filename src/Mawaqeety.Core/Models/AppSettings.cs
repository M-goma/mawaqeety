using Mawaqeety.Core.Calculation;

namespace Mawaqeety.Core.Models;

public enum AlertMode
{
    /// <summary>Windows notification without sound.</summary>
    NotificationOnly,
    /// <summary>Windows notification and the selected sound.</summary>
    NotificationWithSound,
    /// <summary>Sound only, no notification banner.</summary>
    SoundOnly,
    /// <summary>No alert.</summary>
    Off,
}

public enum AppTheme { Dark, Light, System }

public enum AppLanguage { Arabic, English }

public enum TimeSource
{
    /// <summary>Offline astronomical engine only (default, always available).</summary>
    Local,
    /// <summary>Aladhan online API when reachable (cached for offline use), local engine as fallback.</summary>
    OnlineWithLocalFallback,
}

public sealed class PrayerAlertSettings
{
    public bool Enabled { get; set; } = true;
    public AlertMode Mode { get; set; } = AlertMode.NotificationWithSound;
    /// <summary>Full path to a user-selected MP3/WAV. Null or empty = built-in chime.</summary>
    public string? SoundPath { get; set; }
    /// <summary>Manual correction in minutes (+/-) applied to this time.</summary>
    public int AdjustmentMinutes { get; set; }
}

public sealed class AppSettings
{
    public int SchemaVersion { get; set; } = 2;
    public bool FirstRunCompleted { get; set; }

    // Location
    public GeoLocation Location { get; set; } = GeoLocation.Cairo;
    /// <summary>When true, the time zone follows the location's IANA id (automatic DST). When false, ManualUtcOffsetMinutes is used.</summary>
    public bool AutoTimeZone { get; set; } = true;
    public int ManualUtcOffsetMinutes { get; set; } = 120;
    /// <summary>Only used with a manual offset: adds one hour (summer time) on top of the manual offset.</summary>
    public bool ManualDstEnabled { get; set; }

    // Calculation
    public MethodId Method { get; set; } = MethodId.Egyptian;
    public AsrMadhab Madhab { get; set; } = AsrMadhab.Shafii;
    public HighLatitudeRule HighLatitudeRule { get; set; } = HighLatitudeRule.AngleBased;
    public double CustomFajrAngle { get; set; } = 18;
    public double CustomIshaAngle { get; set; } = 17;
    public TimeSource Source { get; set; } = TimeSource.Local;
    public int HijriAdjustmentDays { get; set; }

    // Alerts
    public Dictionary<Prayer, PrayerAlertSettings> Alerts { get; set; } = PrayerExtensions.All.ToDictionary(
        p => p,
        p => new PrayerAlertSettings { Enabled = p != Prayer.Sunrise, Mode = AlertMode.NotificationWithSound });

    /// <summary>Play the selected adhan at prayer time (obligatory prayers, unless a custom sound is set for that prayer).</summary>
    public bool AdhanEnabled { get; set; } = true;
    public string AdhanId { get; set; } = Audio.AdhanCatalog.DefaultId;
    public string FajrAdhanId { get; set; } = Audio.AdhanCatalog.DefaultFajrId;

    public bool PreAlertEnabled { get; set; } = true;
    public int PreAlertMinutes { get; set; } = 10;
    public AlertMode PreAlertMode { get; set; } = AlertMode.NotificationOnly;
    /// <summary>Global master switch to silence all sounds while keeping notifications.</summary>
    public bool MuteAllSounds { get; set; }
    public double Volume { get; set; } = 0.8;
    public DateTimeOffset? PausedUntil { get; set; }

    // UI / system
    public AppTheme Theme { get; set; } = AppTheme.Dark;
    public AppLanguage Language { get; set; } = AppLanguage.Arabic;
    public bool Use24HourClock { get; set; }
    public bool StartWithWindows { get; set; } = true;
    public bool StartMinimized { get; set; } = true;
    public bool MinimizeToTrayOnClose { get; set; } = true;

    // Qur'an reader
    public double QuranFontSize { get; set; } = 30;
    public string ReciterId { get; set; } = Content.Reciters.DefaultId;
    /// <summary>Continue to the next surah when a recitation reaches the end.</summary>
    public bool ContinueToNextSurah { get; set; } = true;
    /// <summary>Narration voice for the prophets' stories: "Male" or "Female".</summary>
    public string NarrationVoice { get; set; } = "Male";
    public int LastReadSurah { get; set; }
    public int LastReadAyah { get; set; }
    /// <summary>Bookmarked ayahs as "surah:ayah".</summary>
    public List<string> Bookmarks { get; set; } = [];

    /// <summary>Interface colour style (see Content.Palette).</summary>
    public string Palette { get; set; } = "emerald";
    /// <summary>Play the next prophet story automatically when one ends.</summary>
    public bool StoryAutoplay { get; set; }

    // Mushaf (printed pages)
    /// <summary>"auto" (follows the app theme), "paper", "white", "navy", "sepia", "charcoal".</summary>
    public string MushafTone { get; set; } = "auto";
    public string MushafNight { get; set; } = "navy";
    /// <summary>Extra dimming inside the Mushaf, 0..0.6.</summary>
    public double MushafDim { get; set; }
    public int MushafPage { get; set; } = 1;

    // Tasbeeh and the daily tracker
    /// <summary>Daily tasbeeh goal (0 = none).</summary>
    public int WirdGoal { get; set; } = 100;
    /// <summary>Ask "did you pray?" about 30 minutes after each prayer.</summary>
    public bool PrayerCheck { get; set; } = true;
    /// <summary>Surat al-Kahf reminder (Thursday after Maghrib and Friday morning).</summary>
    public bool FridayKahf { get; set; } = true;
    /// <summary>The hour of answered prayer on Friday (the last hour before Maghrib).</summary>
    public bool FridayHour { get; set; } = true;
    /// <summary>Show hadiths with their full chain of narrators (default: the text only).</summary>
    public bool HadithFull { get; set; }
    public int TasbeehPhrase { get; set; }
    /// <summary>33, 100, 0 = free counting, -1 = after-prayer sequence (33+33+34).</summary>
    public int TasbeehTarget { get; set; } = 33;
    public List<string> TasbeehCustom { get; set; } = [];
    public int TasbeehCount { get; set; }
    public int TasbeehStep { get; set; }

    // Quran wird and khatma plan (same meaning as the mobile app's khatma* / quran* settings)
    /// <summary>0 = no plan; else finish the Mushaf in this many days.</summary>
    public int KhatmaDays { get; set; }
    /// <summary>yyyy-MM-dd the current khatma began.</summary>
    public string KhatmaStart { get; set; } = "";
    /// <summary>Furthest page reached in the current khatma.</summary>
    public int KhatmaPage { get; set; }
    /// <summary>Completed khatmas.</summary>
    public int KhatmaDone { get; set; }
    /// <summary>yyyy-MM-dd of <see cref="QuranPages"/>.</summary>
    public string QuranDay { get; set; } = "";
    /// <summary>Distinct Mushaf pages read that day.</summary>
    public List<int> QuranPages { get; set; } = [];

    // Zakat calculator
    /// <summary>Price of a gram of 24k gold / pure silver, entered by the user.</summary>
    public double GoldPrice { get; set; }
    public double SilverPrice { get; set; }
    /// <summary>Nisab by silver (595 g) instead of gold (85 g).</summary>
    public bool NisabSilver { get; set; }

    // Desktop widget
    public bool WidgetEnabled { get; set; }
    public bool WidgetTopmost { get; set; } = true;
    public double? WidgetLeft { get; set; }
    public double? WidgetTop { get; set; }

    public PrayerAlertSettings AlertFor(Prayer p)
    {
        if (!Alerts.TryGetValue(p, out var a))
            Alerts[p] = a = new PrayerAlertSettings { Enabled = p != Prayer.Sunrise };
        return a;
    }

    public CalculationOptions ToCalculationOptions()
    {
        var method = Method == MethodId.Custom
            ? CalculationMethod.Custom(CustomFajrAngle, CustomIshaAngle)
            : CalculationMethod.Get(Method);
        return new CalculationOptions(method, Madhab, HighLatitudeRule);
    }

    public IReadOnlyDictionary<Prayer, int> Adjustments() =>
        PrayerExtensions.All.ToDictionary(p => p, p => AlertFor(p).AdjustmentMinutes);

    /// <summary>The zone used to display and schedule times.</summary>
    public TimeZoneInfo ResolveZone()
    {
        if (AutoTimeZone) return TimeZoneResolver.Resolve(Location.TimeZoneId);
        var offset = TimeSpan.FromMinutes(ManualUtcOffsetMinutes + (ManualDstEnabled ? 60 : 0));
        TimeZoneResolver.TryParseFixed(TimeZoneResolver.FixedId(offset), out var z);
        return z;
    }

    /// <summary>Identifies everything that changes computed times (used for cache keys).</summary>
    public string CalculationKey() => FormattableStringInvariant(
        $"{Method}|{Madhab}|{HighLatitudeRule}|{CustomFajrAngle}|{CustomIshaAngle}");

    private static string FormattableStringInvariant(FormattableString s) => FormattableString.Invariant(s);

    public AppSettings Clone() => SettingsSerializer.Deserialize(SettingsSerializer.Serialize(this));
}
