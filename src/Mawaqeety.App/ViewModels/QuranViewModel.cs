using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.App.Services;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed partial class AyahItem : ObservableObject
{
    public int Surah { get; init; }
    public int Number { get; init; }
    public string Text { get; init; } = "";
    public string Mark => "﴿" + QuranRepository.ArabicDigits(Number) + "﴾";
    [ObservableProperty] private bool _isBookmarked;
    [ObservableProperty] private bool _isLastRead;
    [ObservableProperty] private bool _isPlaying;
}

/// <summary>An entry of the left index: a surah, a search hit, a bookmark or "continue reading".</summary>
public sealed record IndexItem(string Kind, int Surah, int Ayah, string Title, string Subtitle, string Badge)
{
    public bool IsHeader => Kind == "header";
}

public sealed partial class QuranViewModel : ObservableObject
{
    private static readonly QuranRepository Q = QuranRepository.Default;
    private const string Basmala = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ";

    public ObservableCollection<IndexItem> Index { get; } = [];
    public ObservableCollection<AyahItem> Ayahs { get; } = [];

    /// <summary>Raised when the view should scroll to an ayah.</summary>
    public event Action<AyahItem>? ScrollRequested;

    [ObservableProperty] private string _filter = "";
    [ObservableProperty] private int _surahNumber = 1;
    [ObservableProperty] private string _surahTitle = "";
    [ObservableProperty] private string _surahInfo = "";
    [ObservableProperty] private bool _showBasmala;
    [ObservableProperty] private string _status = "";

    public string BasmalaText => Basmala;

    // ---------------- Mushaf (printed pages) / text ----------------
    /// <summary>The Qur'an is read as printed Mushaf pages (the plain-text view was removed).</summary>
    public bool IsMushaf => true;

    /// <summary>The side panel with the surahs, bookmarks and search.</summary>
    [ObservableProperty] private bool _indexOpen;

    public MushafViewModel Mushaf => _mushaf ??= new MushafViewModel(this);

    /// <summary>Today's wird and the khatma plan (the card above the Mushaf).</summary>
    public KhatmaViewModel? Khatma => App.Instance.MainVm?.Khatma;
    private MushafViewModel? _mushaf;

    public void StartRecitationAt(int surah, int ayah) => StartRecitation(surah, ayah);

    public void SetLastRead(int surah, int ayah)
    {
        App.Instance.Settings.Update(s => { s.LastReadSurah = surah; s.LastReadAyah = ayah; });
        foreach (var x in Ayahs) x.IsLastRead = x.Surah == surah && x.Number == ayah;
        Status = "تم حفظ موضع القراءة";
        if (Filter.Length == 0) RebuildIndex();
        _mushaf?.AfterPositionChange();
    }

    [RelayCommand]
    public void ClearLastRead()
    {
        App.Instance.Settings.Update(s => { s.LastReadSurah = 0; s.LastReadAyah = 0; });
        foreach (var x in Ayahs) x.IsLastRead = false;
        Status = "تمت إزالة موضع القراءة";
        if (Filter.Length == 0) RebuildIndex();
        _mushaf?.AfterPositionChange();
    }

    public bool IsBookmarked(int surah, int ayah) => App.Instance.Settings.Current.Bookmarks.Contains($"{surah}:{ayah}");

    public void ToggleBookmarkAt(int surah, int ayah)
    {
        var key = $"{surah}:{ayah}";
        App.Instance.Settings.Update(s => { if (!s.Bookmarks.Remove(key)) s.Bookmarks.Add(key); });
        foreach (var x in Ayahs.Where(x => x.Surah == surah && x.Number == ayah)) x.IsBookmarked = IsBookmarked(surah, ayah);
        if (Filter.Length == 0) RebuildIndex();
    }

    public void CopyAyahAt(int surah, int ayah)
    {
        try
        {
            Clipboard.SetText($"﴿{Q[surah].Verses[ayah - 1]}﴾ [{Q[surah].Name}: {ayah}]");
            Status = "تم نسخ الآية";
        }
        catch (Exception ex) { App.Instance.Log.Warn("Clipboard failed", ex); }
    }

    // ---------------- offline downloads ----------------
    public DownloadManager Downloads => App.Instance.Downloads;
    [ObservableProperty] private bool _downloadsOpen;
    [ObservableProperty] private string _reciterSavedText = "";
    [ObservableProperty] private string _mushafSavedText = "";

    partial void OnDownloadsOpenChanged(bool value) { if (value) RefreshSaved(); }

    private void RefreshSaved()
    {
        var id = ReciterId;
        var n = DownloadManager.SavedAyahs(id);
        ReciterSavedText = $"محفوظ على الجهاز: {QuranRepository.ArabicDigits(Math.Min(100, n * 100 / 6237))}٪ من المصحف بصوت {Reciters.Find(id).Name}";
        MushafSavedText = $"محفوظ على الجهاز: {QuranRepository.ArabicDigits(App.Instance.Pages.SavedCount())} من ٦٠٤ صفحة (الحجم الكامل نحو ٦٦ ميجابايت)";
    }

    [RelayCommand]
    private async Task DownloadSurah()
    {
        var surah = IsMushaf ? MushafIndex.Default.SurahOf(Mushaf.RightPage) : SurahNumber;
        await Downloads.DownloadRecitationAsync(ReciterId, [surah]);
        RefreshSaved();
    }

    [RelayCommand]
    private async Task DownloadAllRecitation()
    {
        await Downloads.DownloadRecitationAsync(ReciterId);
        RefreshSaved();
    }

    [RelayCommand] private void CancelRecitationDownload() => Downloads.CancelRecitation();

    [RelayCommand]
    private async Task DownloadMushaf()
    {
        await Downloads.DownloadMushafAsync();
        RefreshSaved();
    }

    [RelayCommand] private void CancelMushafDownload() => Downloads.CancelMushaf();

    public double FontSize
    {
        get => App.Instance.Settings.Current.QuranFontSize;
        set
        {
            App.Instance.Settings.Update(s => s.QuranFontSize = Math.Clamp(value, 18, 56));
            OnPropertyChanged();
            OnPropertyChanged(nameof(MarkFontSize));
        }
    }

    public double MarkFontSize => FontSize * 0.85;

    // ---------------- recitation ----------------
    public IReadOnlyList<Reciter> ReciterList { get; } = Reciters.All;

    public string ReciterId
    {
        get => Reciters.Find(App.Instance.Settings.Current.ReciterId).Id;
        set
        {
            if (value == ReciterId) return;
            var wasPlaying = App.Instance.Recitation.IsPlaying;
            var (surah, ayah) = (App.Instance.Recitation.CurrentSurah, App.Instance.Recitation.CurrentAyah);
            App.Instance.Settings.Update(s => s.ReciterId = value);
            OnPropertyChanged();
            if (wasPlaying && surah > 0) StartRecitation(surah, Math.Max(1, ayah)); // continue with the new voice
        }
    }

    public bool IsReciting => App.Instance.Recitation.IsPlaying;
    public bool IsRecitingPaused => App.Instance.Recitation.IsPaused;
    public string PlayGlyph => IsReciting && !IsRecitingPaused ? "\uE769" : "\uE768";
    public string PlayLabel => !IsReciting ? "استماع" : IsRecitingPaused ? "متابعة" : "إيقاف مؤقت";

    private void StartRecitation(int surah, int ayah)
    {
        var rec = App.Instance.Recitation;
        rec.OnFinished = last =>
        {
            if (!App.Instance.Settings.Current.ContinueToNextSurah || last >= 114) return null;
            var next = last + 1;
            App.Instance.Dispatcher.BeginInvoke(() => Open(next, 1, scroll: true));
            return (next, 1, Q[next].Verses.Count);
        };
        rec.Play(surah, ayah, Q[surah].Verses.Count);
    }

    [RelayCommand]
    private void PlayPause()
    {
        var rec = App.Instance.Recitation;
        if (rec.IsPlaying) { rec.TogglePause(); return; }
        // Start from the selected/last-read ayah of this surah, otherwise from the beginning.
        var s = App.Instance.Settings.Current;
        var start = s.LastReadSurah == SurahNumber && s.LastReadAyah > 0 ? s.LastReadAyah : 1;
        StartRecitation(SurahNumber, start);
    }

    [RelayCommand] private void StopRecitation() => App.Instance.Recitation.Stop();

    [RelayCommand]
    private void PlayFromAyah(AyahItem? a)
    {
        if (a is not null) StartRecitation(a.Surah, a.Number);
    }

    private void OnAyahStarted(int surah, int ayah)
    {
        App.Instance.Dispatcher.BeginInvoke(() =>
        {
            if (surah != SurahNumber) Open(surah, Math.Max(1, ayah), scroll: false);
            AyahItem? current = null;
            foreach (var x in Ayahs)
            {
                x.IsPlaying = x.Number == ayah;
                if (x.IsPlaying) current = x;
            }
            if (current is not null && !IsMushaf) ScrollRequested?.Invoke(current);
            // While listening, the saved reading position moves along with the recitation.
            var st = App.Instance.Settings.Current;
            if (ayah > 0 && (st.LastReadSurah != surah || st.LastReadAyah != ayah))
            {
                App.Instance.Settings.Update(x => { x.LastReadSurah = surah; x.LastReadAyah = ayah; });
                foreach (var x in Ayahs) x.IsLastRead = x.Surah == surah && x.Number == ayah;
            }
        });
    }

    private void OnRecitationState() => App.Instance.Dispatcher.BeginInvoke(() =>
    {
        if (!App.Instance.Recitation.IsPlaying) foreach (var x in Ayahs) x.IsPlaying = false;
        OnPropertyChanged(nameof(IsReciting));
        OnPropertyChanged(nameof(IsRecitingPaused));
        OnPropertyChanged(nameof(PlayGlyph));
        OnPropertyChanged(nameof(PlayLabel));
    });

    public QuranViewModel()
    {
        App.Instance.Recitation.AyahStarted += OnAyahStarted;
        App.Instance.Recitation.StateChanged += OnRecitationState;
        App.Instance.Recitation.Error += msg => App.Instance.Dispatcher.BeginInvoke(() => Status = msg);
        var s = App.Instance.Settings.Current;
        Open(s.LastReadSurah > 0 ? s.LastReadSurah : 1, s.LastReadAyah > 0 ? s.LastReadAyah : 1, scroll: false);
        RebuildIndex();
    }

    partial void OnFilterChanged(string value) => RebuildIndex();

    private void RebuildIndex()
    {
        Index.Clear();
        var s = App.Instance.Settings.Current;
        var f = Filter.Trim();
        if (f.Length == 0)
        {
            if (s.LastReadSurah > 0)
                Index.Add(new IndexItem("continue", s.LastReadSurah, s.LastReadAyah, "متابعة القراءة",
                    $"سورة {Q[s.LastReadSurah].Name} • الآية {QuranRepository.ArabicDigits(s.LastReadAyah)}", ""));
            foreach (var b in ParseBookmarks(s.Bookmarks))
                Index.Add(new IndexItem("bookmark", b.Surah, b.Ayah, $"سورة {Q[b.Surah].Name} : {QuranRepository.ArabicDigits(b.Ayah)}",
                    Shorten(Q[b.Surah].Verses[b.Ayah - 1]), ""));
            foreach (var su in Q.Surahs) Index.Add(SurahItem(su));
            return;
        }

        var key = QuranRepository.Normalize(f);
        foreach (var su in Q.Surahs.Where(x => QuranRepository.Normalize(x.Name).Contains(key) ||
                                                x.NameEn.Contains(f, StringComparison.OrdinalIgnoreCase) || x.Number.ToString() == f))
            Index.Add(SurahItem(su));
        var hits = Q.Search(f);
        if (hits.Count > 0)
        {
            Index.Add(new IndexItem("header", 0, 0, hits.Count >= 300 ? "في الآيات: أكثر من ٣٠٠ نتيجة" : $"في الآيات: {QuranRepository.ArabicDigits(hits.Count)} نتيجة", "", ""));
            foreach (var h in hits)
                Index.Add(new IndexItem("hit", h.Surah.Number, h.Ayah, $"سورة {h.Surah.Name} : {QuranRepository.ArabicDigits(h.Ayah)}", Shorten(h.Text), ""));
        }
    }

    private static IndexItem SurahItem(Surah s) =>
        new("surah", s.Number, 1, $"سورة {s.Name}", $"{(s.Meccan ? "مكية" : "مدنية")} • {QuranRepository.ArabicDigits(s.Verses.Count)} آية",
            QuranRepository.ArabicDigits(s.Number));

    private static string Shorten(string t) => t.Length > 70 ? t[..70] + "…" : t;

    private static IEnumerable<(int Surah, int Ayah)> ParseBookmarks(IEnumerable<string> list)
    {
        foreach (var b in list)
        {
            var p = b.Split(':');
            if (p.Length == 2 && int.TryParse(p[0], out var s) && int.TryParse(p[1], out var a) && s is >= 1 and <= 114 && a >= 1 && a <= Q[s].Verses.Count)
                yield return (s, a);
        }
    }

    [RelayCommand]
    private void OpenIndex(IndexItem? item)
    {
        if (item is null || item.IsHeader) return;
        Open(item.Surah, item.Ayah, scroll: true);
        if (item.Kind != "surah") Mushaf.Flash(item.Surah, item.Ayah);
        IndexOpen = false;
    }

    /// <summary>Opens a surah and scrolls to an ayah (used by the prophets' stories too).</summary>
    public void Open(int surah, int ayah, bool scroll = true)
    {
        surah = Math.Clamp(surah, 1, 114);
        var s = Q[surah];
        ayah = Math.Clamp(ayah, 1, s.Verses.Count);
        var settings = App.Instance.Settings.Current;
        if (surah != SurahNumber || Ayahs.Count == 0)
        {
            SurahNumber = surah;
            SurahTitle = $"سورة {s.Name}";
            SurahInfo = $"{(s.Meccan ? "مكية" : "مدنية")} • آياتها {QuranRepository.ArabicDigits(s.Verses.Count)}";
            ShowBasmala = surah != 1 && surah != 9;
            var marks = ParseBookmarks(settings.Bookmarks).Where(b => b.Surah == surah).Select(b => b.Ayah).ToHashSet();
            Ayahs.Clear();
            for (var i = 0; i < s.Verses.Count; i++)
                Ayahs.Add(new AyahItem
                {
                    Surah = surah, Number = i + 1, Text = s.Verses[i], IsBookmarked = marks.Contains(i + 1),
                    IsLastRead = settings.LastReadSurah == surah && settings.LastReadAyah == i + 1,
                });
        }
        if (scroll) ScrollRequested?.Invoke(Ayahs[ayah - 1]);
        if (scroll)
        {
            Mushaf.GoToAyah(surah, ayah);
            if (ayah > 1) Mushaf.Flash(surah, ayah);
        }
    }

    [RelayCommand] private void NextSurah() { if (SurahNumber < 114) Open(SurahNumber + 1, 1); }
    [RelayCommand] private void PrevSurah() { if (SurahNumber > 1) Open(SurahNumber - 1, 1); }

    [RelayCommand]
    private void SaveLastRead(AyahItem? a)
    {
        if (a is null) return;
        foreach (var x in Ayahs) x.IsLastRead = x == a;
        App.Instance.Settings.Update(s => { s.LastReadSurah = a.Surah; s.LastReadAyah = a.Number; });
        Status = "تم حفظ موضع القراءة";
        if (Filter.Length == 0) RebuildIndex();
    }

    [RelayCommand]
    private void ToggleBookmark(AyahItem? a)
    {
        if (a is null) return;
        var key = $"{a.Surah}:{a.Number}";
        App.Instance.Settings.Update(s =>
        {
            if (!s.Bookmarks.Remove(key)) s.Bookmarks.Add(key);
        });
        a.IsBookmarked = !a.IsBookmarked;
        if (Filter.Length == 0) RebuildIndex();
    }

    [RelayCommand]
    private void CopyAyah(AyahItem? a)
    {
        if (a is null) return;
        try
        {
            Clipboard.SetText($"﴿{a.Text}﴾ [{Q[a.Surah].Name}: {a.Number}]");
            Status = "تم نسخ الآية";
        }
        catch (Exception ex) { App.Instance.Log.Warn("Clipboard failed", ex); }
    }

    [RelayCommand] private void FontUp() => FontSize += 2;
    [RelayCommand] private void FontDown() => FontSize -= 2;
}
