using Mawaqeety.Core.Content;
using Xunit;

namespace Mawaqeety.Tests;

/// <summary>
/// «سبيل» must know every section of the app (same rule as mobile/test/sabeel_library_test.dart): an embedded content
/// resource that no <see cref="LibrarySource"/> lists breaks this test. Register the new section in SabeelLibrary.Sources.
/// </summary>
public class SabeelLibraryTests
{
    private static readonly SabeelLibrary L = SabeelLibrary.Default;

    private static List<string> Top(string q, int n = SabeelLibrary.Shown) => L.Search(q).Entries.Take(n).Select(e => e.Id).ToList();

    [Fact]
    public void Every_content_resource_is_registered()
    {
        const string prefix = "Mawaqeety.Core.Resources.";
        var resources = typeof(Sabeel).Assembly.GetManifestResourceNames()
            .Where(n => n.StartsWith(prefix, StringComparison.Ordinal)).Select(n => n[prefix.Length..]).ToList();
        Assert.NotEmpty(resources);
        var covered = SabeelLibrary.CoveredResources;
        Assert.Equal([], resources.Where(r => !covered.Contains(r) && !SabeelLibrary.NotContent.Contains(r)).ToList());
        Assert.Equal([], covered.Where(r => !resources.Contains(r)).ToList());
    }

    [Fact]
    public void Every_source_has_entries_with_unique_ids()
    {
        Assert.Equal(L.Entries.Count, L.Entries.Select(e => e.Id).Distinct().Count());
        Assert.All(SabeelLibrary.Sources, s => Assert.Contains(L.Entries, e => e.Section == s.Section));
    }

    [Fact]
    public void Sample_queries()
    {
        Assert.Equal("ghazawat:badr", Top("غزوة بدر")[0]);
        Assert.Contains("ghazawat:badr", Top("متى كانت غزوة بدر؟"));
        Assert.Contains(Top("المسح على الخفين"), id => id.StartsWith("fiqh:", StringComparison.Ordinal));
        Assert.StartsWith("fiqh:", Top("ما حكم المسح على الجوارب؟")[0]);
        Assert.Contains("companions_islam:umar", Top("إسلام عمر"));
        Assert.Contains("companions_islam:abubakr", Top("كيف أسلم أبو بكر؟"));
        Assert.Contains("feature:zakat", Top("نصاب الزكاة"));
        Assert.Equal("feature:zakat", Top("حاسبة الزكاة")[0]);
        Assert.Contains("occasions:arafah", Top("صيام عرفة"));
        Assert.Contains("prophets:yusuf", Top("قصة يوسف"));
        Assert.Contains("arbaeen:1", Top("إنما الأعمال بالنيات"));
        Assert.Empty(L.Search("xyzxyz").Entries);
    }

    [Fact]
    public void Sabeel_puts_app_content_first_for_rulings_and_battles()
    {
        var fiqh = Sabeel.Default.Ask("ما حكم المسح على الجوارب؟");
        Assert.True(fiqh.Ruling);
        Assert.True(fiqh.LibraryFirst);
        Assert.NotNull(fiqh.Library.Entries[0].Source);
        Assert.True(Sabeel.Default.Ask("غزوة بدر").LibraryFirst);
        var kursi = Sabeel.Default.Ask("تفسير آية الكرسي");
        Assert.Equal(255, Assert.Single(kursi.Ayat).Ayah);
        Assert.False(kursi.LibraryFirst);
    }
}
