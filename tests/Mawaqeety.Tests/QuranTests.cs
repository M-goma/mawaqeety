using Mawaqeety.Core.Content;

namespace Mawaqeety.Tests;

public class QuranTests
{
    private static readonly QuranRepository Q = QuranRepository.Default;

    [Fact]
    public void Full_mushaf_is_embedded()
    {
        Assert.Equal(114, Q.Surahs.Count);
        Assert.Equal(6236, Q.Surahs.Sum(s => s.Verses.Count));
        Assert.Equal(286, Q[2].Verses.Count);
        Assert.Equal("الفاتحة", Q[1].Name);
        Assert.Equal(6, Q[114].Verses.Count);
    }

    [Fact]
    public void Search_ignores_diacritics()
    {
        var hits = Q.Search("الحمد لله رب العالمين");
        Assert.Contains(hits, h => h.Surah.Number == 1 && h.Ayah == 2);
        Assert.Empty(Q.Search("ا"));
        Assert.Contains(Q.Search("الرحمن الرحيم"), h => h.Surah.Number == 1 && h.Ayah == 3);
        Assert.Contains(Q.Search("قل هو الله احد"), h => h.Surah.Number == 112 && h.Ayah == 1);
    }

    [Fact]
    public void Stories_of_25_prophets_with_valid_verse_references()
    {
        Assert.Equal(25, Q.Prophets.Count);
        Assert.Equal("آدم", Q.Prophets[0].NameAr);
        foreach (var p in Q.Prophets)
        {
            Assert.NotEmpty(p.Sections);
            foreach (var a in p.Ayat)
            {
                Assert.InRange(a.Surah, 1, 114);
                Assert.InRange(a.From, 1, Q[a.Surah].Verses.Count);
                Assert.InRange(a.To, a.From, Q[a.Surah].Verses.Count);
            }
        }
    }

    [Fact]
    public void Arabic_digits() => Assert.Equal("٢٨٦", QuranRepository.ArabicDigits(286));
}
