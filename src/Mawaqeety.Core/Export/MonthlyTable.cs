namespace Mawaqeety.Core.Export;

/// <summary>Language-neutral table passed to exporters (text is already localized by the caller).</summary>
public sealed record MonthlyTable(
    string Title,
    string Subtitle,
    IReadOnlyList<string> Headers,
    IReadOnlyList<IReadOnlyList<string>> Rows,
    bool RightToLeft,
    int HighlightRow = -1,
    string Footer = "");
