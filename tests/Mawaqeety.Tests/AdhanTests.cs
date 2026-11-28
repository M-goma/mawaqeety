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
    public void Url_encoding_escapes_the_arabic_file_name()
    {
        var url = AdhanCatalog.Find("minshawi")!.Url;
        Assert.StartsWith(AdhanCatalog.BaseUrl + "Mohamed_Siddiq_El-Minshawi_-_Egypt_1_%28", url);
        Assert.EndsWith("%29.mp3", url);
    }

    [Fact]
    public void Alafasy_was_removed_and_old_settings_move_to_the_defaults()
    {
        Assert.DoesNotContain(AdhanCatalog.All, v => v.Id.Contains("afasy") || v.Id.Contains("mishary"));
        var s = Mawaqeety.Core.SettingsSerializer.Deserialize("{\"AdhanId\":\"alafasy\",\"FajrAdhanId\":\"alafasy-fajr\",\"ReciterId\":\"Alafasy_128kbps\"}");
        Assert.Equal(AdhanCatalog.DefaultId, s.AdhanId);
        Assert.Equal(AdhanCatalog.DefaultFajrId, s.FajrAdhanId);
        Assert.Equal(Mawaqeety.Core.Content.Reciters.DefaultId, s.ReciterId);
    }

    [Fact]
    public void Full_collection_is_available_with_readable_unique_names()
    {
        Assert.True(AdhanCatalog.All.Count > 200);
        Assert.Equal(AdhanCatalog.All.Count, AdhanCatalog.All.Select(v => v.NameAr).Distinct().Count());
        Assert.True(AdhanCatalog.ForFajr.First().IsFajr);
        // ids saved by v1.1 must still resolve
        foreach (var id in new[] { "makkah-mala", "madinah", "aqsa", "abdulbasit", "refaat", "hussary", "minshawi",
                     "banna", "mustafa-ismail", "qatami", "makkah-fajr", "madinah-fajr", "cairo-fajr" })
            Assert.NotNull(AdhanCatalog.Find(id));
    }
}
