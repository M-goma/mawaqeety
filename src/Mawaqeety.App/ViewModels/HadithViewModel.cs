using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Services;

namespace Mawaqeety.App.ViewModels;

public sealed partial class HadithItem(Hadith h, HadithViewModel owner) : ObservableObject
{
    public Hadith H { get; } = h;
    public string Text => owner.ShowFull || !H.HasMatn ? H.Text : H.Matn;
    public string Reference => $"{H.Collection.Name} • {QuranRepository.ArabicDigits(H.Number)} • {H.Collection.BookName(H.Book)}";
    public void Refresh() => OnPropertyChanged(nameof(Text));
}

public sealed record HadithBookItem(int Number, string Name, string CountText)
{
    public string NumberText => QuranRepository.ArabicDigits(Number);
}

/// <summary>Sahih al-Bukhari and Sahih Muslim: hadith of the day, the books, search; the text alone or with its chain.</summary>
public sealed partial class HadithViewModel : ObservableObject
{
    [ObservableProperty] private string _collectionId = "bukhari";
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private HadithItem? _today;
    [ObservableProperty] private string _query = "";
    [ObservableProperty] private HadithBookItem? _book;
    public ObservableCollection<HadithBookItem> Books { get; } = [];
    public ObservableCollection<HadithItem> Items { get; } = [];

    public bool ShowFull
    {
        get => App.Instance.Settings.Current.HadithFull;
        set
        {
            App.Instance.Settings.Update(s => s.HadithFull = value);
            OnPropertyChanged();
            Today?.Refresh();
            foreach (var i in Items) i.Refresh();
        }
    }

    public bool IsBukhari => CollectionId == "bukhari";

    public HadithViewModel() => LoadCollection();

    partial void OnCollectionIdChanged(string value)
    {
        OnPropertyChanged(nameof(IsBukhari));
        LoadCollection();
    }

    [RelayCommand] private void ShowBukhari() => CollectionId = "bukhari";
    [RelayCommand] private void ShowMuslim() => CollectionId = "muslim";

    private HadithCollection Col => HadithCollection.Load(CollectionId);

    private void LoadCollection()
    {
        Today = new HadithItem(HadithCollection.Load("bukhari").OfDay(App.Instance.Today), this);
        Books.Clear();
        foreach (var (n, _) in Col.Books) Books.Add(new HadithBookItem(n, Col.BookName(n), Count(Col.BookCount(n))));
        Items.Clear();
        Book = null;
        Title = Col.Name;
        Status = $"{QuranRepository.ArabicDigits(Col.Books.Count)} كتابًا • اختر كتابًا أو ابحث";
    }

    private static string Count(int n) => n switch
    {
        1 => "حديث واحد",
        2 => "حديثان",
        <= 10 => $"{QuranRepository.ArabicDigits(n)} أحاديث",
        _ => $"{QuranRepository.ArabicDigits(n)} حديثًا",
    };

    partial void OnBookChanged(HadithBookItem? value)
    {
        if (value is null) return;
        Items.Clear();
        foreach (var h in Col.InBook(value.Number)) Items.Add(new HadithItem(h, this));
        Title = value.Name;
        Status = Count(Items.Count);
    }

    [RelayCommand]
    private void Search()
    {
        if (string.IsNullOrWhiteSpace(Query)) return;
        var r = Col.Search(Query);
        Book = null;
        Items.Clear();
        foreach (var h in r) Items.Add(new HadithItem(h, this));
        Title = $"نتائج البحث: {Query}";
        Status = r.Count == 0 ? "لا توجد نتائج" : Count(r.Count) + (r.Count >= 150 ? " (أول ١٥٠)" : "");
    }

    [RelayCommand]
    private static void Copy(HadithItem? h)
    {
        if (h is null) return;
        try { Clipboard.SetText($"{h.Text}\n\n[{h.H.Collection.Name}، رقم {h.H.Number}]"); } catch { /* clipboard busy */ }
    }
}

/// <summary>The ten companions promised Paradise.</summary>
public sealed partial class CompanionsViewModel : ObservableObject
{
    public CompanionsBook Book => CompanionsBook.Default;
    public IReadOnlyList<Companion> List => Book.Companions;
    [ObservableProperty] private Companion? _selected;
    public CompanionsViewModel() => Selected = List[0];
}
