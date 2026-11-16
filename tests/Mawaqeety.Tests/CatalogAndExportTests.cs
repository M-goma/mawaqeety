using Mawaqeety.Core.Export;
using Mawaqeety.Core.Geo;

namespace Mawaqeety.Tests;

public class CatalogAndExportTests
{
    [Theory]
    [InlineData("القاهرة", "Cairo")]
    [InlineData("قاهره", "Cairo")]
    [InlineData("cairo", "Cairo")]
    [InlineData("الاسكندرية", "Alexandria")]
    [InlineData("مكه", "Makkah")]
    [InlineData("Sao Paulo", "Sao Paulo")]
    [InlineData("el mansoura", "Mansoura")]
    public void Search_is_tolerant_to_arabic_and_latin_variants(string q, string expected)
    {
        Assert.Equal(expected, CityCatalog.Default.Search(q).First().NameEn);
    }

    [Fact]
    public void Catalog_contains_all_27_egyptian_governorate_capitals()
    {
        string[] capitals = ["Cairo", "Giza", "Alexandria", "Banha", "Port Said", "Suez", "Ismailia", "Damietta", "Mansoura",
            "Tanta", "Zagazig", "Shibin El Kom", "Kafr El Sheikh", "Damanhur", "Marsa Matruh", "Faiyum", "Beni Suef", "Minya",
            "Asyut", "Sohag", "Qena", "Luxor", "Aswan", "Hurghada", "Kharga", "Arish", "El Tor"];
        var names = CityCatalog.Default.Cities.Where(c => c.CountryCode == "EG").Select(c => c.NameEn).ToHashSet();
        Assert.Equal(27, capitals.Length);
        Assert.All(capitals, c => Assert.Contains(c, names));
    }

    [Fact]
    public void All_catalog_time_zones_resolve()
    {
        foreach (var c in CityCatalog.Default.Cities)
            Assert.Equal(c.TimeZoneId, TimeZoneInfo.FindSystemTimeZoneById(c.TimeZoneId).Id);
    }

    [Fact]
    public void Nearest_city_works()
    {
        var (city, km) = CityCatalog.Default.Nearest(30.05, 31.24);
        Assert.Equal("Cairo", city.NameEn);
        Assert.True(km < 5);
    }

    private static MonthlyTable Sample(bool rtl) => new("مواقيت الصلاة - نوفمبر 2026", "القاهرة، مصر",
        ["التاريخ", "هجري", "الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"],
        Enumerable.Range(1, 30).Select(i => (IReadOnlyList<string>)[$"{i}/11/2026", "1448", "04:45", "06:10", "11:40", "14:40", "17:00", "18:20"]).ToList(),
        rtl, HighlightRow: 15, Footer: "Mawaqeety");

    [Fact]
    public void Excel_export_creates_valid_file()
    {
        var path = Path.Combine(Path.GetTempPath(), $"mw-{Guid.NewGuid():N}.xlsx");
        ExcelExporter.Export(Sample(true), path);
        Assert.True(new FileInfo(path).Length > 4000);
        using var wb = new ClosedXML.Excel.XLWorkbook(path);
        Assert.Equal("الفجر", wb.Worksheet(1).Cell(4, 3).GetString());
        File.Delete(path);
    }

    [Fact]
    public void Pdf_export_creates_valid_file()
    {
        var font = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "src", "Mawaqeety.App", "Assets", "Fonts", "Cairo-Regular.ttf"));
        if (File.Exists(font)) PdfExporter.Initialize([File.OpenRead(font)]);
        var path = Path.Combine(Path.GetTempPath(), $"mw-{Guid.NewGuid():N}.pdf");
        PdfExporter.Export(Sample(true), path);
        var bytes = File.ReadAllBytes(path);
        Assert.True(bytes.Length > 2000);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(bytes, 0, 4));
        File.Delete(path);
    }
}
