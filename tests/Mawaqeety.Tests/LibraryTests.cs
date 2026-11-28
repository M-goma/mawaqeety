using Mawaqeety.Core;
using Mawaqeety.Core.Content;
using Xunit;

namespace Mawaqeety.Tests;

/// <summary>Content ported from the mobile app: الأربعون، الفقه، أسباب النزول، الغزوات، النسب، إسلام الصحابة، الأطلس، التقويم.</summary>
public class LibraryTests
{
    [Fact]
    public void Arbaeen_has_42_hadiths_whose_sahih_references_resolve()
    {
        var b = ArbaeenBook.Default;
        Assert.Equal(42, b.Hadiths.Count);
        Assert.Equal(Enumerable.Range(1, 42), b.Hadiths.Select(h => h.Number));
        Assert.All(b.Hadiths, h => Assert.False(string.IsNullOrWhiteSpace(h.Text)));
        Assert.Equal("الأول", ArbaeenBook.Ordinal(1));
        Assert.Equal("الحادي عشر", ArbaeenBook.Ordinal(11));
        Assert.Equal("الثاني والأربعون", ArbaeenBook.Ordinal(42));
        Assert.Equal("العشرون", ArbaeenBook.Ordinal(20));
        var refs = b.Hadiths.SelectMany(h => (h.Sahih ?? []).Concat(h.Related ?? [])).ToList();
        Assert.NotEmpty(refs);
        Assert.All(refs, r => Assert.Equal(r.Number, r.Resolve()?.Number));
        Assert.Contains(b.Hadiths, h => h.Extra is not null);
    }

    [Fact]
    public void Fiqh_items_have_sources_and_search_ignores_diacritics()
    {
        var f = FiqhBook.Default;
        Assert.True(f.Items.Count > 50);
        Assert.All(f.Items, i => Assert.NotEmpty(i.Answers));
        Assert.All(f.Items.SelectMany(i => i.Answers), a => Assert.StartsWith("https://", a.Url));
        Assert.Contains("الطهارة", f.Topics);
        Assert.Contains(f.Items, i => i.Khilaf);
        Assert.NotEmpty(f.Filter(null, "التيمم"));
        Assert.Equal(f.Filter(null, "التيمم").Count(), f.Filter(null, "التَّيَمُّم").Count());
        Assert.Empty(f.Filter(null, "zzzz"));
        Assert.All(f.Filter("الصلاة", ""), i => Assert.Equal("الصلاة", i.Topic));
    }

    [Fact]
    public void Asbab_point_at_real_ayat_and_hadiths()
    {
        var a = Asbab.Default;
        Assert.True(a.All.Count > 100);
        Assert.All(a.All, s =>
        {
            Assert.InRange(s.From, 1, s.To);
            Assert.True(s.To <= QuranRepository.Default[s.Surah].Verses.Count);
        });
        Assert.All(a.All.Take(40), s => Assert.Equal(s.Number, s.Hadith()?.Number));
        Assert.NotEmpty(a.InSurah(2));
    }

    [Fact]
    public void Ghazawat_are_sorted_and_complete()
    {
        var g = GhazawatBook.Default;
        Assert.Equal(10, g.Items.Count);
        Assert.Equal(g.Items.OrderBy(x => x.Year).Select(x => x.Id), g.Items.Select(x => x.Id));
        Assert.Equal("badr", g.Items[0].Id);
        Assert.Contains(g.Items, x => !x.IsBattle);
        Assert.All(g.Items, x => Assert.NotEmpty(x.Sections));
        Assert.All(g.Items.SelectMany(x => x.Hadith), h => Assert.NotNull(h.Find()));
        Assert.Equal("https://github.com/M-goma/mawaqeety/releases/download/stories-audio/ghazwa-badr-mazen.mp3", g.Items[0].AudioUrl);
    }

    [Fact]
    public void Nasab_and_companions_islam_were_converted_from_the_dart_data()
    {
        var n = NasabBook.Default;
        Assert.Equal(22, n.Chain.Count);
        Assert.Equal("محمد ﷺ", n.Chain[0].Name);
        Assert.Equal("عدنان", n.Chain[^1].Name);
        Assert.Equal(10, n.Companions.Count);
        Assert.All(n.Companions, c => Assert.Equal(n.Chain[c.Meet].Name, c.Chain[^1]));
        Assert.All(n.Companions, c => Assert.StartsWith("https://", c.Source.Url));

        var c = CompanionsIslamBook.Default;
        Assert.Equal(10, c.List.Count);
        Assert.All(c.List, x => Assert.NotEmpty(x.Sources));
        Assert.Contains(c.List, x => x.AgeDisputed);
        // the quoted hadith numbers exist in the bundled Bukhari
        Assert.All(c.List.Where(x => x.Hadith is not null), x => Assert.NotNull(SahihLookup.Find("bukhari", x.Hadith!.Number)));
    }

    [Fact]
    public void Atlas_places_name_known_prophets()
    {
        var ids = QuranRepository.Default.Prophets.Select(p => p.Id).ToHashSet();
        var a = AtlasBook.Default;
        Assert.Equal(13, a.Places.Count);
        Assert.All(a.Places, p => Assert.All(p.Prophets, id => Assert.Contains(id, ids)));
        Assert.Equal("ثابت بالنص", a.Places[0].CertaintyLabel);
        Assert.Contains("mlat=21.4225", a.Places[0].MapUrl);
    }

    [Fact]
    public void Calendar_events_mark_occasions_and_white_days()
    {
        // 1 Ramadan 1447 (Umm al-Qura) = 18 February 2026
        var start = HijriDate.ToGregorian(1447, 9, 1);
        Assert.Contains("بداية شهر رمضان", CalendarEvents.On(start));
        Assert.DoesNotContain(CalendarEvents.On(start.AddDays(1)), e => e.StartsWith("بداية "));
        var white = HijriDate.ToGregorian(1447, 8, 13);
        Assert.Contains("الأيام البيض", CalendarEvents.On(white));
        Assert.DoesNotContain("الأيام البيض", CalendarEvents.On(HijriDate.ToGregorian(1447, 9, 13)));
        Assert.Contains("بداية شعبان", CalendarEvents.On(HijriDate.ToGregorian(1447, 8, 1)));
        Assert.Contains("صيام يوم عرفة", CalendarEvents.On(HijriDate.ToGregorian(1447, 12, 9)));
    }
}
