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
