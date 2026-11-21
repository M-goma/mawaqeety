using Mawaqeety.Core.Audio;
using Mawaqeety.Core.Models;

namespace Mawaqeety.Tests;

public class AdhanTests
{
    [Fact]
    public void Adhan_plays_at_prayer_time_with_fajr_specific_voice()
    {
        var s = new AppSettings();
        Assert.Equal(AdhanCatalog.DefaultId, AlertSoundResolver.Resolve(Prayer.Dhuhr, AlertKind.AtTime, s).Adhan?.Id);
        Assert.Equal(AdhanCatalog.DefaultFajrId, AlertSoundResolver.Resolve(Prayer.Fajr, AlertKind.AtTime, s).Adhan?.Id);
    }

    [Fact]
    public void Reminders_and_sunrise_use_chime_not_adhan()
    {
        var s = new AppSettings();
        Assert.Equal(AlertSound.Chime, AlertSoundResolver.Resolve(Prayer.Asr, AlertKind.PreAlert, s));
        Assert.Equal(AlertSound.Chime, AlertSoundResolver.Resolve(Prayer.Sunrise, AlertKind.AtTime, s));
    }

    [Fact]
    public void Custom_file_wins_and_disabling_adhan_falls_back_to_chime()
    {
        var s = new AppSettings();
        s.AlertFor(Prayer.Maghrib).SoundPath = @"C:\my.mp3";
        Assert.Equal(@"C:\my.mp3", AlertSoundResolver.Resolve(Prayer.Maghrib, AlertKind.AtTime, s).CustomPath);
        s.AdhanEnabled = false;
        Assert.Equal(AlertSound.Chime, AlertSoundResolver.Resolve(Prayer.Isha, AlertKind.AtTime, s));
    }

    [Fact]
    public void Unknown_voice_id_falls_back_to_default()
    {
        var s = new AppSettings { AdhanId = "does-not-exist" };
        Assert.Equal(AdhanCatalog.DefaultId, AlertSoundResolver.Resolve(Prayer.Isha, AlertKind.AtTime, s).Adhan?.Id);
    }

    [Fact]
    public void Catalog_ids_are_unique_and_urls_are_escaped()
    {
        Assert.Equal(AdhanCatalog.All.Count, AdhanCatalog.All.Select(v => v.Id).Distinct().Count());
        Assert.All(AdhanCatalog.All, v =>
        {
            Assert.StartsWith(AdhanCatalog.BaseUrl, v.Url);
            Assert.DoesNotContain(" ", v.Url);
            Assert.EndsWith(".mp3", v.FileName);
        });
        Assert.NotNull(AdhanCatalog.Find(AdhanCatalog.DefaultId));
        Assert.True(AdhanCatalog.Find(AdhanCatalog.DefaultFajrId)!.IsFajr);
    }

    [Fact]
    public void Old_settings_without_adhan_fields_get_adhan_enabled()
    {
        var json = """{ "SchemaVersion": 1, "Language": "Arabic" }""";
        var s = Mawaqeety.Core.SettingsSerializer.Deserialize(json);
        Assert.True(s.AdhanEnabled);
        Assert.Equal(AdhanCatalog.DefaultId, s.AdhanId);
    }

    [Fact]
    public void Url_encoding_matches_verified_raw_github_url()
    {
        // This exact URL was verified to return a valid MP3 (ID3 header) from raw.githubusercontent.com.
        Assert.Equal("https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Mishary_Rashid_Alafasy_1_-_Kuwait_%28%D9%85%D8%B4%D8%A7%D8%B1%D9%8A_%D8%B1%D8%A7%D8%B4%D8%AF_%D8%A7%D9%84%D8%B9%D9%81%D8%A7%D8%B3%D9%8A_-_%D8%A7%D9%84%D9%83%D9%88%D9%8A%D8%AA%29.mp3", AdhanCatalog.Find("alafasy")!.Url);
    }
}
