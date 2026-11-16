using System.Collections.ObjectModel;
using System.Diagnostics;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using Mawaqeety.App.Localization;
using Mawaqeety.Core;
using Mawaqeety.Core.Export;
using Mawaqeety.Core.Models;

namespace Mawaqeety.App.ViewModels;

public sealed record DayRow(string Date, string DayName, string Hijri, string Fajr, string Sunrise, string Dhuhr,
    string Asr, string Maghrib, string Isha, bool IsToday, bool IsFriday);

public sealed partial class MonthlyViewModel : ObservableObject
{
    private int _year = DateTime.Today.Year;
    private int _month = DateTime.Today.Month;

    public ObservableCollection<DayRow> Days { get; } = [];

    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _subtitle = "";
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private string? _lastExportPath;

    public MonthlyViewModel()
    {
        Loc.I.LanguageChanged += (_, _) => Reload();
        App.Instance.Settings.Changed += _ => App.Instance.Dispatcher.BeginInvoke(Reload);
    }

    public void Reload()
    {
        var app = App.Instance;
        var s = app.Settings.Current;
        var loc = Loc.I;
        var first = new DateTime(_year, _month, 1);
        var monthName = first.ToString("MMMM yyyy", loc.Culture);
        var h1 = HijriDate.From(DateOnly.FromDateTime(first), s.HijriAdjustmentDays);
        var h2 = HijriDate.From(DateOnly.FromDateTime(first.AddMonths(1).AddDays(-1)), s.HijriAdjustmentDays);
        var hijriRange = h1.Month == h2.Month ? $"{h1.MonthName(loc.IsArabic)} {h1.Year}" : $"{h1.MonthName(loc.IsArabic)} – {h2.MonthName(loc.IsArabic)} {h2.Year}";
        Title = string.Format(loc["MonthlyTitle"], monthName);
        Subtitle = $"{s.Location.DisplayName(loc.IsArabic)}  •  {hijriRange}";

        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.Now, s.ResolveZone()).DateTime);
        Days.Clear();
        foreach (var d in app.Times.GetMonth(_year, _month, s))
        {
            string T(DateTimeOffset t) => loc.FormatTime(t, s.Use24HourClock);
            var dt = d.Date.ToDateTime(TimeOnly.MinValue);
            var h = HijriDate.From(d.Date, s.HijriAdjustmentDays);
            Days.Add(new DayRow(dt.ToString("d MMM", loc.Culture), dt.ToString("dddd", loc.Culture), $"{h.Day} {h.MonthName(loc.IsArabic)}",
                T(d.Fajr), T(d.Sunrise), T(d.Dhuhr), T(d.Asr), T(d.Maghrib), T(d.Isha), d.Date == today, dt.DayOfWeek == DayOfWeek.Friday));
        }
        Status = "";
    }

    [RelayCommand]
    private void PrevMonth() { Shift(-1); }

    [RelayCommand]
    private void NextMonth() { Shift(1); }

    [RelayCommand]
    private void ThisMonth()
    {
        _year = DateTime.Today.Year;
        _month = DateTime.Today.Month;
        Reload();
    }

    private void Shift(int delta)
    {
        var d = new DateTime(_year, _month, 1).AddMonths(delta);
        _year = d.Year;
        _month = d.Month;
        Reload();
    }

    private MonthlyTable BuildTable()
    {
        var loc = Loc.I;
        var headers = new[] { loc["Date"], loc["Hijri"], loc["Fajr"], loc["Sunrise"], loc["Dhuhr"], loc["Asr"], loc["Maghrib"], loc["Isha"] };
        var rows = Days.Select(d => (IReadOnlyList<string>)[$"{d.DayName} {d.Date}", d.Hijri, d.Fajr, d.Sunrise, d.Dhuhr, d.Asr, d.Maghrib, d.Isha]).ToList();
        var todayIndex = Days.ToList().FindIndex(d => d.IsToday);
        return new MonthlyTable(Title, Subtitle, headers, rows, loc.IsArabic, todayIndex,
            $"{loc["AppName"]} – {loc["Slogan"]}");
    }

    [RelayCommand]
    private void ExportExcel() => Export("xlsx", "Excel (*.xlsx)|*.xlsx", ExcelExporter.Export);

    [RelayCommand]
    private void ExportPdf() => Export("pdf", "PDF (*.pdf)|*.pdf", PdfExporter.Export);

    private void Export(string ext, string filter, Action<MonthlyTable, string> exporter)
    {
        var dlg = new SaveFileDialog
        {
            Filter = filter,
            FileName = $"Mawaqeety-{_year}-{_month:00}.{ext}",
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        };
        if (dlg.ShowDialog() != true) return;
        try
        {
            exporter(BuildTable(), dlg.FileName);
            LastExportPath = dlg.FileName;
            Status = Loc.T("ExportDone");
        }
        catch (Exception ex)
        {
            App.Instance.Log.Error("Export failed", ex);
            LastExportPath = null;
            Status = string.Format(Loc.T("ExportFailed"), ex.Message);
        }
    }

    [RelayCommand]
    private void OpenExport()
    {
        if (LastExportPath is { } p && File.Exists(p))
            Process.Start(new ProcessStartInfo(p) { UseShellExecute = true });
    }
}
