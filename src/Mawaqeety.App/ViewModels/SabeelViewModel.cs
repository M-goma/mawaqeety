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

/// <summary>An entry «من محتوى التطبيق»: its section, title and a short quote; opening it goes to its page.</summary>
public sealed record SabeelLibraryItem(LibraryEntry E)
{
    public string Section => E.Section;
    public string Title => E.Title;
    public string Snippet => E.Snippet;
    public bool HasSnippet => E.Snippet.Length > 0;
    public string Source => E.Source is { } s ? $"المصدر: {s}" : "";
    public bool HasSource => E.Source is not null;
    public bool IsFeature => E.Feature;
    public string OpenLabel => E.Feature ? "افتح الصفحة" : "اقرأ في قسمه";
}

/// <summary>
/// «اسأل سبيل»: ask about an ayah's tafsir, a hadith or anything in the app; answers quote the Quran, التفسير الميسر,
/// the two Sahih collections and the app's own sections (fiqh, battles, companions…), offline.
/// </summary>
public sealed partial class SabeelViewModel : ObservableObject
{
    public IReadOnlyList<string> Examples { get; } =
    [
        "ما حكم المسح على الجوارب؟", "متى كانت غزوة بدر؟", "كيف أسلم أبو بكر؟", "نصاب الزكاة", "تفسير آية الكرسي", "الكهف 10",
        "الصبر", "حديث إنما الأعمال بالنيات",
    ];

    public const string Disclaimer = "سبيل بحث آلي في النصوص وليس مفتيًا. المصادر: المصحف (رواية حفص)، التفسير الميسر — مجمع الملك فهد لطباعة المصحف الشريف، صحيح البخاري وصحيح مسلم، وأقسام التطبيق بمصادرها المذكورة في كل قسم.";
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
    [ObservableProperty] private IReadOnlyList<SabeelLibraryItem> _libraryBefore = [];
    [ObservableProperty] private IReadOnlyList<SabeelLibraryItem> _libraryAfter = [];
    [ObservableProperty] private string _libraryMoreText = "";
    [ObservableProperty] private bool _showMoreBefore;
    [ObservableProperty] private bool _showMoreAfter;
    private IReadOnlyList<SabeelLibraryItem> _libraryAll = [];
    private bool _libraryFirst;

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
        _libraryAll = a.Library.Entries.Select(e => new SabeelLibraryItem(e)).ToList();
        _libraryFirst = a.LibraryFirst;
        ShowLibrary(_libraryAll.Take(SabeelLibrary.Shown).ToList());
        IsBusy = false;
        HasAnswer = true;
    }

    private void ShowLibrary(IReadOnlyList<SabeelLibraryItem> shown)
    {
        LibraryBefore = _libraryFirst ? shown : [];
        LibraryAfter = _libraryFirst ? [] : shown;
        var rest = _libraryAll.Count - shown.Count;
        LibraryMoreText = rest > 0 ? $"المزيد ({Ui.D(rest)})" : "";
        ShowMoreBefore = _libraryFirst && rest > 0;
        ShowMoreAfter = !_libraryFirst && rest > 0;
    }

    [RelayCommand] private void MoreLibrary() => ShowLibrary(_libraryAll);

    /// <summary>Opens an entry in its page (one case per <see cref="LibrarySource"/> id).</summary>
    [RelayCommand]
    private static void OpenEntry(SabeelLibraryItem? x)
    {
        if (x is null || App.Instance.MainVm is not { } m) return;
        var id = x.E.TargetId;
        switch (x.E.Target)
        {
            case "fiqh":
                m.Page = Page.Fiqh;
                m.Fiqh.Query = x.E.Title;
                break;
            case "ghazawat":
                m.Page = Page.Ghazawat;
                if (m.Ghazawat.Items.FirstOrDefault(g => g.G.Id == id) is { } g) m.Ghazawat.Selected = g;
                break;
            case "companions_islam":
                m.Page = Page.CompanionsIslam;
                break;
            case "companions":
                m.Page = Page.Companions;
                if (m.Companions.List.FirstOrDefault(c => c.Id == id) is { } c) m.Companions.Selected = c;
                break;
            case "nasab":
                m.Page = Page.Nasab;
                if (m.Nasab.Companions.FirstOrDefault(n => n.C.Id == id) is { } n) m.Nasab.Selected = n;
                break;
            case "prophets":
                m.Page = Page.Prophets;
                if (m.Prophets.Prophets.FirstOrDefault(p => p.Prophet.Id == id) is { } p) m.Prophets.Selected = p;
                break;
            case "arbaeen":
                m.Page = Page.Arbaeen;
                if (m.Arbaeen.Items.FirstOrDefault(h => h.H.Number.ToString() == id) is { } h) m.Arbaeen.Selected = h;
                break;
            case "asbab":
                m.Page = Page.Asbab;
                m.Asbab.Filter = "all";
                if (m.Asbab.Surahs.FirstOrDefault(s => s.Surah.Number.ToString() == id) is { } s) m.Asbab.Selected = s;
                break;
            case "asma":
                m.Page = Page.Asma;
                m.Asma.Query = id;
                break;
            case "occasions":
                m.Page = Page.Occasions;
                break;
            case "duas":
                m.Page = Page.Adhkar;
                m.Adhkar.Group = m.Adhkar.DuaGroups.FirstOrDefault(d => d.Id == id) ?? m.Adhkar.Group;
                m.Adhkar.ShowDuasCommand.Execute(null);
                break;
            case "adhkar":
                m.Page = Page.Adhkar;
                break;
            case "atlas":
                m.Page = Page.Atlas;
                break;
            case "feature":
                if (Enum.TryParse<Page>(id, out var page)) m.NavigateCommand.Execute(page);
                break;
        }
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
