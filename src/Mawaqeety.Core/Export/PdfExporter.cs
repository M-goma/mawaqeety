using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Mawaqeety.Core.Export;

public static class PdfExporter
{
    private static readonly object Gate = new();
    private static bool _initialized;
    public const string FontFamily = "Cairo";

    /// <summary>
    /// QuestPDF Community license is free for individuals and organizations below USD 1M annual revenue.
    /// Review https://www.questpdf.com/license/ before commercial distribution.
    /// </summary>
    public static void Initialize(IEnumerable<Stream> fontStreams)
    {
        lock (Gate)
        {
            if (_initialized) return;
            QuestPDF.Settings.License = LicenseType.Community;
            foreach (var s in fontStreams)
                QuestPDF.Drawing.FontManager.RegisterFontFromStream(s);
            _initialized = true;
        }
    }

    public static void Export(MonthlyTable t, string path)
    {
        Initialize([]);
        var navy = "#0B1F3A";
        var emerald = "#0E8A5F";
        var gold = "#C9A227";

        Document.Create(doc => doc.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(28);
            page.DefaultTextStyle(x => x.FontFamily(FontFamily).FontSize(9.5f));
            if (t.RightToLeft) page.ContentFromRightToLeft();

            page.Header().Column(col =>
            {
                col.Item().AlignCenter().Text(t.Title).FontSize(18).Bold().FontColor(navy);
                col.Item().AlignCenter().Text(t.Subtitle).FontSize(11).FontColor(emerald);
                col.Item().PaddingTop(6).LineHorizontal(1.5f).LineColor(gold);
            });

            page.Content().PaddingTop(10).Table(table =>
            {
                table.ColumnsDefinition(c =>
                {
                    for (var i = 0; i < t.Headers.Count; i++)
                        if (i < 2) c.RelativeColumn(1.6f); else c.RelativeColumn();
                });
                table.Header(h =>
                {
                    foreach (var head in t.Headers)
                        h.Cell().Background(navy).Padding(5).AlignCenter().Text(head).FontColor(Colors.White).Bold();
                });
                for (var r = 0; r < t.Rows.Count; r++)
                {
                    var bg = r == t.HighlightRow ? "#F6E7B8" : (r % 2 == 1 ? "#EEF5F1" : "#FFFFFF");
                    foreach (var cell in t.Rows[r])
                    {
                        var text = table.Cell().Background(bg).BorderBottom(0.5f).BorderColor("#D9E2DC")
                            .PaddingVertical(3.5f).PaddingHorizontal(4).AlignCenter().Text(cell);
                        if (r == t.HighlightRow) text.Bold();
                    }
                }
            });

            page.Footer().AlignCenter().Text(x =>
            {
                x.Span(t.Footer).FontSize(8).FontColor(Colors.Grey.Darken1);
                x.Span("   ").FontSize(8);
                x.CurrentPageNumber().FontSize(8).FontColor(Colors.Grey.Darken1);
            });
        })).GeneratePdf(path);
    }
}
