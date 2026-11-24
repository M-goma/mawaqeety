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

    [Fact]
    public void Recitation_urls_and_basmala_order()
    {
        Assert.Equal("https://everyayah.com/data/Alafasy_128kbps/002255.mp3", Reciters.Url("Alafasy_128kbps", 2, 255));
        var seq = Reciters.Sequence(2, 1, 3);
        Assert.True(seq[0].IsBasmala);
        Assert.Equal((2, 1, false), seq[1]);
        Assert.False(Reciters.Sequence(1, 1, 7)[0].IsBasmala);   // Al-Fatiha: basmala is ayah 1
        Assert.False(Reciters.Sequence(9, 1, 5)[0].IsBasmala);   // At-Tawbah: no basmala
        Assert.Equal(3, Reciters.Sequence(2, 5, 7).Count);
        Assert.Equal(Reciters.DefaultId, Reciters.Find("unknown").Id);
        Assert.True(Reciters.All.Count >= 10);
    }
}
