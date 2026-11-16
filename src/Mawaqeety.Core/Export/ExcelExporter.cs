using ClosedXML.Excel;

namespace Mawaqeety.Core.Export;

public static class ExcelExporter
{
    public static void Export(MonthlyTable t, string path)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Mawaqeety");
        ws.RightToLeft = t.RightToLeft;

        var cols = t.Headers.Count;
        ws.Cell(1, 1).Value = t.Title;
        ws.Range(1, 1, 1, cols).Merge().Style.Font.SetBold().Font.SetFontSize(16)
            .Font.SetFontColor(XLColor.FromHtml("#0B1F3A")).Alignment.SetHorizontal(XLAlignmentHorizontalValues.Center);
        ws.Cell(2, 1).Value = t.Subtitle;
        ws.Range(2, 1, 2, cols).Merge().Style.Font.SetFontColor(XLColor.FromHtml("#0E8A5F"))
            .Alignment.SetHorizontal(XLAlignmentHorizontalValues.Center);

        const int headerRow = 4;
        for (var c = 0; c < cols; c++) ws.Cell(headerRow, c + 1).Value = t.Headers[c];
        var header = ws.Range(headerRow, 1, headerRow, cols);
        header.Style.Font.SetBold().Font.SetFontColor(XLColor.White)
            .Fill.SetBackgroundColor(XLColor.FromHtml("#0B1F3A"))
            .Alignment.SetHorizontal(XLAlignmentHorizontalValues.Center);

        for (var r = 0; r < t.Rows.Count; r++)
        {
            for (var c = 0; c < cols; c++)
                ws.Cell(headerRow + 1 + r, c + 1).Value = t.Rows[r][c];
            var row = ws.Range(headerRow + 1 + r, 1, headerRow + 1 + r, cols);
            row.Style.Alignment.SetHorizontal(XLAlignmentHorizontalValues.Center);
            if (r == t.HighlightRow)
                row.Style.Fill.SetBackgroundColor(XLColor.FromHtml("#F6E7B8")).Font.SetBold();
            else if (r % 2 == 1)
                row.Style.Fill.SetBackgroundColor(XLColor.FromHtml("#EEF5F1"));
        }

        var table = ws.Range(headerRow, 1, headerRow + t.Rows.Count, cols);
        table.Style.Border.SetOutsideBorder(XLBorderStyleValues.Thin).Border.SetInsideBorder(XLBorderStyleValues.Hair)
            .Border.SetOutsideBorderColor(XLColor.FromHtml("#C9A227"));

        if (t.Footer.Length > 0)
            ws.Cell(headerRow + t.Rows.Count + 2, 1).Value = t.Footer;

        ws.Columns(1, cols).AdjustToContents();
        ws.SheetView.FreezeRows(headerRow);
        wb.SaveAs(path);
    }
}
