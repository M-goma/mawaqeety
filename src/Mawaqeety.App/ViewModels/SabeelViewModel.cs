using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

/// <summary>Small formatting helpers shared by the pages.</summary>
public static class Ui
{
    public static string D(int n) => QuranRepository.ArabicDigits(n);
    public static string D(string s) => string.Concat(s.Select(c => c is >= '0' and <= '9' ? (char)('٠' + (c - '0')) : c));
    public static string Date(DateOnly d) => d.ToDateTime(TimeOnly.MinValue).ToString("dddd، d MMMM yyyy", Localization.Loc.I.Culture);
    public static string Hijri(DateOnly d) { var h = Core.HijriDate.From(d, App.Instance.Settings.Current.HijriAdjustmentDays); return $"{D(h.Day)} {h.MonthName(true)}"; }
    public static Core.HijriDate HijriOf(DateOnly d) => Core.HijriDate.From(d, App.Instance.Settings.Current.HijriAdjustmentDays);
    public static DateOnly FromHijri(int y, int m, int d) => Core.HijriDate.ToGregorian(y, m, d, App.Instance.Settings.Current.HijriAdjustmentDays);
}

public sealed record SabeelAyahItem(SabeelAyah A)
{
    public string Text => $"{A.Text} ﴿{Ui.D(A.Ayah)}﴾";
    public string Tafsir => A.Tafsir;
    public string Reference => $"{A.Surah.Name} • {Ui.D(A.Ayah)}";
}

public sealed record SabeelHadithItem(Hadith H)
{
    public string Text => App.Instance.Settings.Current.HadithFull || !H.HasMatn ? H.Text : H.Matn;
    public string Reference => $"{H.Collection.Name} • {Ui.D(H.Number)} • {H.Collection.BookName(H.Book)}";
}

/// <summary>«اسأل سبيل»: ask about an ayah's tafsir or a hadith; answers quote the Quran, التفسير الميسر and the two Sahih collections, offline.</summary>
public sealed partial class SabeelViewModel : ObservableObject
{
    public IReadOnlyList<string> Examples { get; } = ["تفسير آية الكرسي", "الكهف 10", "خواتيم البقرة", "الصبر", "بر الوالدين", "حديث إنما الأعمال بالنيات"];

    public const string Disclaimer = "سبيل بحث آلي في النصوص وليس مفتيًا. المصادر: المصحف (رواية حفص)، التفسير الميسر — مجمع الملك فهد لطباعة المصحف الشريف، صحيح البخاري وصحيح مسلم.";
    public string DisclaimerText => Disclaimer;

    [ObservableProperty] private string _query = "";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private bool _hasAnswer;
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private bool _ruling;
    [ObservableProperty] private bool _isEmpty;
    [ObservableProperty] private bool _more;
    [ObservableProperty] private IReadOnlyList<SabeelAyahItem> _ayat = [];
    [ObservableProperty] private IReadOnlyList<SabeelHadithItem> _hadith = [];
    [ObservableProperty] private string _copied = "";

    public bool ShowIntro => !HasAnswer && !IsBusy;
    partial void OnHasAnswerChanged(bool value) => OnPropertyChanged(nameof(ShowIntro));
    partial void OnIsBusyChanged(bool value) => OnPropertyChanged(nameof(ShowIntro));

    private int _gen;

    [RelayCommand]
    public async Task Ask(string? q)
    {
        q = (q ?? Query).Trim();
        if (q.Length == 0) return;
        Query = q;
        Copied = "";
        IsBusy = true;
        HasAnswer = false;
        var gen = ++_gen;
        SabeelAnswer a;
        try { a = await Task.Run(() => Sabeel.Default.Ask(q)); }
        catch (Exception ex)
        {
            App.Instance.Log.Warn("Sabeel search failed", ex);
            a = new SabeelAnswer("", [], []);
        }
        if (gen != _gen) return;
        Title = a.Title;
        Ruling = a.Ruling;
        IsEmpty = a.IsEmpty;
        More = a.More;
        Ayat = a.Ayat.Select(x => new SabeelAyahItem(x)).ToList();
        Hadith = a.Hadith.Select(h => new SabeelHadithItem(h)).ToList();
        IsBusy = false;
        HasAnswer = true;
    }

    [RelayCommand]
    private static void OpenInMushaf(SabeelAyahItem? x)
    {
        if (x is null) return;
        App.Instance.OpenMushaf(MushafIndex.Default.PageOf(x.A.Surah.Number, x.A.Ayah), (x.A.Surah.Number, x.A.Ayah));
    }

    [RelayCommand]
    private void CopyAyah(SabeelAyahItem? x)
    {
        if (x is null) return;
        try
        {
            Clipboard.SetText($"﴿{x.A.Text}﴾ [{x.A.Surah.Name}: {x.A.Ayah}]\n\nالتفسير الميسر: {x.A.Tafsir}");
            Copied = "نُسخت الآية وتفسيرها";
        }
        catch { /* clipboard busy */ }
    }

    [RelayCommand]
    private void CopyHadith(SabeelHadithItem? h)
    {
        if (h is null) return;
        try
        {
            Clipboard.SetText($"{h.Text}\n\n[{h.H.Collection.Name}، رقم {h.H.Number}]");
            Copied = "نُسخ الحديث";
        }
        catch { /* clipboard busy */ }
    }
}
