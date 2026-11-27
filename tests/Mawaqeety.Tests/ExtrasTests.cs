using Mawaqeety.Core.Content;
using Xunit;

namespace Mawaqeety.Tests;

public class ExtrasTests
{
    [Fact]
    public void Mushaf_pages_and_ayah_boxes_cover_the_whole_quran()
    {
        var m = MushafIndex.Default;
        Assert.Equal(1, m.PageOf(1, 1));
        Assert.Equal(2, m.PageOf(2, 1));
        Assert.Equal(50, m.PageOf(3, 1));
        Assert.Equal(604, m.PageOf(114, 6));
        Assert.Equal(15, m.JuzOf(300));
        Assert.Equal((3, 1), m.StartOf(50));
        var total = Enumerable.Range(1, MushafIndex.PageCount).Sum(p => m.AyahsOn(p).Count);
        Assert.Equal(6236, total);
        Assert.All(Enumerable.Range(1, MushafIndex.PageCount), p => Assert.All(m.AyahsOn(p), b => Assert.NotEmpty(b.Rects)));
        // every ayah's box is on the page the index says
        foreach (var p in new[] { 1, 50, 300, 604 })
            Assert.All(m.AyahsOn(p), b => Assert.Equal(p, m.PageOf(b.Surah, b.Ayah)));
        var third = m.AyahsOn(50).Single(b => b.Ayah == 3);
        var r = third.Rects[0];
        Assert.True(third.Contains((r.L + r.R) / 2, (r.T + r.B) / 2));
    }

    [Fact]
    public void Qibla_from_cairo_is_south_east()
    {
        var b = Qibla.Bearing(30.0444, 31.2357);
        Assert.InRange(b, 134, 138);
        Assert.Equal("الجنوب الشرقي", Qibla.DirectionName(b));
        Assert.InRange(Qibla.DistanceKm(30.0444, 31.2357), 1200, 1350);
    }

    [Fact]
    public void Adhkar_palettes_and_story_recordings_load()
    {
        Assert.True(Dhikr.All.Count >= 20);
        Assert.Contains(Dhikr.All, d => d.Quran.Count > 0);
        Assert.Equal(10, Palette.All.Count);
        Assert.Equal("emerald", Palette.Find("missing").Id);
        Assert.Equal(2, StoryAudio.Default.Parts("adam", "Male").Count);
        Assert.Equal("female-musa-1.mp3", StoryAudio.Default.Parts("musa", "Female")[0]);
        Assert.Empty(StoryAudio.Default.Parts("nobody", "Male"));
    }
}

public class TrackerTests
{
    [Fact]
    public void Tracker_saves_and_computes_streaks()
    {
        var file = Path.Combine(Path.GetTempPath(), $"tracker-{Guid.NewGuid():N}.json");
        var t = new Mawaqeety.Core.Tracking.Tracker(file) { WirdGoal = () => 100 };
        var today = new DateOnly(2026, 11, 26);
        foreach (var d in new[] { today.AddDays(-2), today.AddDays(-1) })
            foreach (var p in Mawaqeety.Core.Tracking.DayLog.Tracked)
                t.SetPrayer(d, p, Mawaqeety.Core.Tracking.PrayerLog.Mosque);
        t.SetPrayer(today, Mawaqeety.Core.Models.Prayer.Fajr, Mawaqeety.Core.Tracking.PrayerLog.Alone);
        t.SetAdhkar(today, morning: true);
        t.AddTasbeeh(today, 100);
        Assert.Equal(2, t.PrayersStreak(today));          // today not complete yet → counts from yesterday
        Assert.Equal(2, t.FajrMosqueStreak(today));
        Assert.Equal(3 / 8.0, t.Completion(today), 3);   // fajr + morning + wird
        var reloaded = new Mawaqeety.Core.Tracking.Tracker(file);
        Assert.Equal(Mawaqeety.Core.Tracking.PrayerLog.Alone, reloaded.Day(today).Of(Mawaqeety.Core.Models.Prayer.Fajr));
        Assert.Equal(100, reloaded.Day(today).Tasbeeh);
        Assert.Equal(11, reloaded.Distribution(today.AddDays(-2), today).Values.Sum());
        File.Delete(file);
    }

    [Fact]
    public void OccasionDuasLoadWithSources()
    {
        var book = Mawaqeety.Core.Content.DuaBook.Default;
        Assert.Equal(15, book.Groups.Count);
        Assert.Equal(108, book.Groups.Sum(g => g.Count));
        var travel = book.Groups.Single(g => g.Id == "travel");
        static string Plain(string t) => new(t.Where(c => c < '\u064B' || c > '\u0652').ToArray());
        Assert.Contains(travel.Sections, s => s.Title == "دعاء السفر" && Plain(s.Items[0].Text).Contains("سبحان الذي سخر لنا هذا"));
        // Every dua has a source: its own, or the section's list from the book.
        foreach (var g in book.Groups)
            foreach (var s in g.Sections)
                Assert.True(s.Items.All(d => !string.IsNullOrWhiteSpace(d.Source)) || s.Sources is { Count: > 0 }, s.Title);
    }

    [Fact]
    public void SahihCollectionsLoadSearchAndPickADailyHadith()
    {
        var b = Mawaqeety.Core.Content.HadithCollection.Load("bukhari");
        var m = Mawaqeety.Core.Content.HadithCollection.Load("muslim");
        Assert.Equal(97, b.Books.Count);
        Assert.True(b.All.Count > 7500 && m.All.Count > 7000);
        Assert.Equal("كتاب الأدب", b.BookName(78));
        // Bukhari 6018: "whoever believes in Allah and the Last Day…", text-only view starts at the companion.
        var h = b.All.First(x => x.Number == 6018);
        Assert.StartsWith("عَنْ أَبِي هُرَيْرَةَ", h.Matn);
        Assert.Contains(b.Search("فليقل خيرا او ليصمت"), x => x.Number == 6018);
        // Muslim uses the common numbering (e.g. 1907 for "actions are by intentions").
        Assert.Contains(m.Search("انما الاعمال بالنيه"), x => x.Number == 1907);
        var today = b.OfDay(new DateOnly(2026, 11, 27));
        Assert.True(today.HasMatn && today.Matn.Length <= 330);
    }

    [Fact]
    public void TenCompanionsHaveSourcedSituations()
    {
        var c = Mawaqeety.Core.Content.CompanionsBook.Default;
        Assert.Equal(10, c.Companions.Count);
        Assert.All(c.Companions, x => Assert.True(x.Situations.Count >= 2 && x.Situations.All(s => s.Source.Contains("صحيح"))));
    }
}
