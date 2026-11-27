using System.Collections.ObjectModel;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.App.Services;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

/// <summary>Reading colours. The page images are grey (white paper, black ink); each tone maps paper → Bg and ink → Fg.</summary>
public sealed record MushafTone(string Id, string Label, Color Bg, Color Fg, bool Dark)
{
    public static readonly IReadOnlyList<MushafTone> All =
    [
        new("paper", "ورق كريمي", Color.FromRgb(0xFB, 0xF5, 0xE6), Color.FromRgb(0x1F, 0x1A, 0x14), false),
        new("white", "أبيض", Colors.White, Colors.Black, false),
        new("navy", "ليلي كحلي", Color.FromRgb(0x12, 0x18, 0x21), Color.FromRgb(0xEC, 0xE0, 0xC4), true),
        new("sepia", "ليلي بنّي", Color.FromRgb(0x22, 0x1B, 0x14), Color.FromRgb(0xF0, 0xE2, 0xC4), true),
        new("charcoal", "ليلي فحمي", Color.FromRgb(0x1E, 0x1E, 0x1E), Color.FromRgb(0xDC, 0xDC, 0xDC), true),
    ];

    public static MushafTone Find(string id) => All.FirstOrDefault(t => t.Id == id) ?? All[0];
    public SolidColorBrush BgBrush => Frozen(Bg);
    public SolidColorBrush FgBrush => Frozen(Fg);
    public SolidColorBrush MutedBrush => Frozen(ThemeService.Mix(Fg, Bg, 0.45));
    public SolidColorBrush HighlightBrush => Frozen(Dark ? Color.FromArgb(0x33, 0xE9, 0xC7, 0x5A) : Color.FromArgb(0x29, 0x10, 0x96, 0x6A));
    private static SolidColorBrush Frozen(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }
}

public sealed record HighlightRect(double X, double Y, double W, double H);
public sealed record ToneOption(string Id, string Label, SolidColorBrush Bg, SolidColorBrush Fg);
public sealed record NumberedName(int Number, string Name);

/// <summary>One printed page on screen.</summary>
public sealed partial class MushafPageVm : ObservableObject
{
    public int Number { get; init; }
    [ObservableProperty] private ImageSource? _image;
    [ObservableProperty] private bool _loading = true;
    [ObservableProperty] private bool _failed;
    [ObservableProperty] private bool _ribbon;
    public ObservableCollection<HighlightRect> Highlights { get; } = [];
    public string NumberText => QuranRepository.ArabicDigits(Number);
    public string SurahText => $"سورة {QuranRepository.Default[MushafIndex.Default.SurahOf(Number)].Name}";
    public string JuzText
    {
        get
        {
            var (hizb, q) = MushafIndex.Default.HizbOf(Number);
            var quarter = new[] { "", "ربع ", "نصف ", "ثلاثة أرباع " }[q];
            return $"الجزء {QuranRepository.ArabicDigits(MushafIndex.Default.JuzOf(Number))} • {quarter}الحزب {QuranRepository.ArabicDigits(hizb)}";
        }
    }
}

/// <summary>The Mushaf as printed pages: two facing pages like an open book (one page on narrow windows).</summary>
public sealed partial class MushafViewModel : ObservableObject
{
    private static readonly MushafIndex Idx = MushafIndex.Default;
    private readonly QuranViewModel _quran;
    public QuranViewModel Quran => _quran;
    private readonly Dictionary<int, (byte[] Gray, int W, int H)> _gray = [];
    private readonly LinkedList<int> _lru = new();
    private int _loadGen;

    public MushafViewModel(QuranViewModel quran)
    {
        _quran = quran;
        _page = Math.Clamp(App.Instance.Settings.Current.MushafPage, 1, MushafIndex.PageCount);
        App.Instance.Recitation.AyahStarted += (s, a) => App.Instance.Dispatcher.BeginInvoke(() => OnRecitation(s, a));
        App.Instance.Recitation.StateChanged += () => App.Instance.Dispatcher.BeginInvoke(UpdateHighlights);
        ThemeService.Changed += () => { OnPropertyChanged(nameof(Tone)); Retint(); };
        Show();
    }

    public IReadOnlyList<NumberedName> SurahList { get; } = QuranRepository.Default.Surahs.Select(s => new NumberedName(s.Number, $"{QuranRepository.ArabicDigits(s.Number)}. {s.Name}")).ToList();
    public IReadOnlyList<NumberedName> JuzList { get; } = Enumerable.Range(1, 30).Select(j => new NumberedName(j, $"الجزء {QuranRepository.ArabicDigits(j)}")).ToList();
    public IReadOnlyList<ToneOption> Tones { get; } =
        [new("auto", "تلقائي (حسب وضع البرنامج)", Brush(Colors.Gray), Brush(Colors.White)),
         .. MushafTone.All.Select(t => new ToneOption(t.Id, t.Label, t.BgBrush, t.FgBrush))];

    private static SolidColorBrush Brush(Color c) { var b = new SolidColorBrush(c); b.Freeze(); return b; }

    // ---------------- layout ----------------
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(RightPage), nameof(LeftPage), nameof(PageText))]
    private int _page;

    [ObservableProperty] private MushafPageVm? _right;
    [ObservableProperty] private MushafPageVm? _left;

    private bool _twoPages = true;
    /// <summary>Set by the view: two facing pages when the window is wide enough.</summary>
    public bool TwoPages
    {
        get => _twoPages;
        set { if (SetProperty(ref _twoPages, value)) Show(); }
    }

    public int RightPage => TwoPages ? (Page % 2 == 1 ? Page : Page - 1) : Page;
    public int? LeftPage => TwoPages && RightPage + 1 <= MushafIndex.PageCount ? RightPage + 1 : null;
    public string PageText => LeftPage is { } l ? $"{QuranRepository.ArabicDigits(RightPage)}–{QuranRepository.ArabicDigits(l)}" : QuranRepository.ArabicDigits(RightPage);

    public int SelectedSurah
    {
        get => Idx.SurahOf(RightPage);
        set { if (value != SelectedSurah) GoTo(Idx.PageOf(value, 1)); }
    }

    public int SelectedJuz
    {
        get => Idx.JuzOf(RightPage);
        set { if (value != SelectedJuz) GoTo(Idx.JuzStartPage(value)); }
    }

    [ObservableProperty] private string _pageInput = "";

    [RelayCommand]
    private void GoToInput()
    {
        var t = new string(PageInput.Select(c => c is >= '٠' and <= '٩' ? (char)('0' + (c - '٠')) : c).ToArray());
        if (int.TryParse(t, out var p)) GoTo(p);
        PageInput = "";
    }

    public void GoTo(int page)
    {
        page = Math.Clamp(page, 1, MushafIndex.PageCount);
        if (page == RightPage || page == LeftPage) return;
        Page = page;
        App.Instance.Settings.Update(s => s.MushafPage = RightPage);
        Show();
    }

    /// <summary>Opens the page of an ayah (from the index, a bookmark or a story).</summary>
    public void GoToAyah(int surah, int ayah) => GoTo(Idx.PageOf(surah, ayah));

    [RelayCommand] private void NextPage() => GoTo((LeftPage ?? RightPage) + 1);
    [RelayCommand] private void PrevPage() => GoTo(RightPage - 1);

    // ---------------- colours ----------------
    public string ToneId
    {
        get => App.Instance.Settings.Current.MushafTone;
        set
        {
            if (value == ToneId) return;
            App.Instance.Settings.Update(s =>
            {
                s.MushafTone = value;
                if (MushafTone.Find(value).Dark && value != "auto") s.MushafNight = value;
            });
            OnPropertyChanged();
            OnPropertyChanged(nameof(Tone));
            Retint();
        }
    }

    public MushafTone Tone
    {
        get
        {
            var s = App.Instance.Settings.Current;
            if (s.MushafTone != "auto") return MushafTone.Find(s.MushafTone);
            return ThemeService.IsDark ? MushafTone.Find(s.MushafNight) : MushafTone.Find("paper");
        }
    }

    /// <summary>0 (none) .. 0.6: extra dimming inside the Mushaf, independent of the screen brightness.</summary>
    public double Dim
    {
        get => App.Instance.Settings.Current.MushafDim;
        set { App.Instance.Settings.Update(s => s.MushafDim = Math.Clamp(value, 0, 0.6)); OnPropertyChanged(); OnPropertyChanged(nameof(Brightness)); }
    }

    /// <summary>The same setting as a brightness slider (0.4..1).</summary>
    public double Brightness
    {
        get => 1 - Dim;
        set => Dim = 1 - value;
    }

    [RelayCommand] private void SelectTone(string? id) { if (id is not null) ToneId = id; }

    [ObservableProperty] private double _zoom = 1;
    [RelayCommand] private void ZoomIn() => Zoom = Math.Min(3, Math.Round(Zoom + 0.25, 2));
    [RelayCommand] private void ZoomOut() => Zoom = Math.Max(1, Math.Round(Zoom - 0.25, 2));
    [RelayCommand] private void ZoomReset() => Zoom = 1;

    // ---------------- pages ----------------
    private void Show()
    {
        var gen = ++_loadGen;
        Right = NewPage(RightPage, gen);
        Left = LeftPage is { } l ? NewPage(l, gen) : null;
        // The pages on screen count as read for today's wird and the khatma plan.
        App.Instance.NoteQuranPage(RightPage);
        if (LeftPage is { } lp) App.Instance.NoteQuranPage(lp);
        OnPropertyChanged(nameof(SelectedSurah));
        OnPropertyChanged(nameof(SelectedJuz));
        OnPropertyChanged(nameof(PageText));
        OnPropertyChanged(nameof(ReadHere));
        UpdateHighlights();
        // Prefetch the next spread so turning the page is instant.
        foreach (var p in new[] { (LeftPage ?? RightPage) + 1, (LeftPage ?? RightPage) + 2, RightPage - 1 })
            if (p is >= 1 and <= MushafIndex.PageCount) _ = App.Instance.Pages.LoadAsync(p);
    }

    private MushafPageVm NewPage(int number, int gen)
    {
        var vm = new MushafPageVm { Number = number };
        _ = LoadAsync(vm, gen);
        return vm;
    }

    private async Task LoadAsync(MushafPageVm vm, int gen)
    {
        try
        {
            var g = await GrayAsync(vm.Number);
            if (gen != _loadGen) return;
            if (g is null) { vm.Failed = true; vm.Loading = false; return; }
            var tone = Tone;
            vm.Image = await Task.Run(() => Tint(g.Value, tone));
            vm.Loading = false;
            vm.Failed = false;
        }
        catch (Exception ex)
        {
            App.Instance.Log.Warn($"Showing Mushaf page {vm.Number} failed", ex);
            vm.Failed = true;
            vm.Loading = false;
        }
    }

    [RelayCommand]
    private void Retry(MushafPageVm? vm)
    {
        if (vm is null) return;
        vm.Failed = false;
        vm.Loading = true;
        _ = LoadAsync(vm, _loadGen);
    }

    private async Task<(byte[] Gray, int W, int H)?> GrayAsync(int page)
    {
        if (_gray.TryGetValue(page, out var hit)) return hit;
        var bytes = await App.Instance.Pages.LoadAsync(page);
        if (bytes is null) return null;
        var g = await Task.Run(() =>
        {
            var dec = new PngBitmapDecoder(new MemoryStream(bytes), BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
            var gray = new FormatConvertedBitmap(dec.Frames[0], PixelFormats.Gray8, null, 0);
            int w = gray.PixelWidth, h = gray.PixelHeight;
            var px = new byte[w * h];
            gray.CopyPixels(px, w, 0);
            return (px, w, h);
        });
        _gray[page] = g;
        _lru.AddFirst(page);
        while (_lru.Count > 10)
        {
            _gray.Remove(_lru.Last!.Value);
            _lru.RemoveLast();
        }
        return g;
    }

    /// <summary>Recolours a grey page: each grey level becomes a mix of the tone's ink and paper colours.</summary>
    private static BitmapSource Tint((byte[] Gray, int W, int H) g, MushafTone t)
    {
        var colors = new List<Color>(256);
        for (var i = 0; i < 256; i++) colors.Add(ThemeService.Mix(t.Fg, t.Bg, i / 255.0));
        var bmp = BitmapSource.Create(g.W, g.H, 96, 96, PixelFormats.Indexed8, new BitmapPalette(colors), g.Gray, g.W);
        bmp.Freeze();
        return bmp;
    }

    private void Retint()
    {
        var tone = Tone;
        foreach (var vm in new[] { Right, Left })
        {
            if (vm is null || !_gray.TryGetValue(vm.Number, out var g)) continue;
            vm.Image = Tint(g, tone);
        }
        UpdateHighlights();
    }

    // ---------------- ayah highlight ----------------
    private (int Surah, int Ayah)? _selected;

    /// <summary>The ayah under a point of a page (image pixels), or null.</summary>
    public AyahBox? AyahAt(int page, double x, double y) => Idx.AyahsOn(page).FirstOrDefault(b => b.Contains(x, y));

    private System.Windows.Threading.DispatcherTimer? _flash;

    /// <summary>Highlights an ayah for a few seconds (opened from search, a bookmark or a story).</summary>
    public void Flash(int surah, int ayah)
    {
        Select((surah, ayah));
        _flash?.Stop();
        _flash = new System.Windows.Threading.DispatcherTimer(TimeSpan.FromSeconds(4), System.Windows.Threading.DispatcherPriority.Normal,
            (_, _) => { _flash?.Stop(); if (_selected == (surah, ayah)) Select(null); }, App.Instance.Dispatcher);
        _flash.Start();
    }

    public void Select((int Surah, int Ayah)? ayah)
    {
        _selected = ayah;
        UpdateHighlights();
    }

    private void OnRecitation(int surah, int ayah)
    {
        if (!_quran.IsMushaf || surah < 1) { UpdateHighlights(); return; }
        var p = Idx.PageOf(surah, Math.Max(1, ayah));
        if (p != RightPage && p != LeftPage && Zoom <= 1.01) GoTo(p);
        UpdateHighlights();
    }

    public void UpdateHighlights()
    {
        var rec = App.Instance.Recitation;
        (int, int)? target = _selected ?? (rec.IsPlaying && rec.CurrentAyah > 0 ? (rec.CurrentSurah, rec.CurrentAyah) : null);
        var s = App.Instance.Settings.Current;
        foreach (var vm in new[] { Right, Left })
        {
            if (vm is null) continue;
            vm.Highlights.Clear();
            vm.Ribbon = s.LastReadSurah > 0 && Idx.PageOf(s.LastReadSurah, s.LastReadAyah) == vm.Number;
            if (target is not { } t) continue;
            var box = Idx.AyahsOn(vm.Number).FirstOrDefault(b => b.Surah == t.Item1 && b.Ayah == t.Item2);
            if (box is null) continue;
            foreach (var r in box.Rects) vm.Highlights.Add(new HighlightRect(r.L, r.T, r.R - r.L, r.B - r.T));
        }
    }

    // ---------------- actions ----------------
    public bool ReadHere
    {
        get
        {
            var s = App.Instance.Settings.Current;
            return s.LastReadSurah > 0 && (Idx.PageOf(s.LastReadSurah, s.LastReadAyah) is var p) && (p == RightPage || p == LeftPage);
        }
    }

    /// <summary>Saves the reading position at the first ayah of the right page, or removes it when it is on these pages.</summary>
    [RelayCommand]
    private void ToggleReadHere()
    {
        if (ReadHere) _quran.ClearLastRead();
        else
        {
            var (su, a) = Idx.StartOf(RightPage);
            _quran.SetLastRead(su, a);
        }
        OnPropertyChanged(nameof(ReadHere));
        UpdateHighlights();
    }

    public void AfterPositionChange()
    {
        OnPropertyChanged(nameof(ReadHere));
        UpdateHighlights();
    }

    /// <summary>Plays from the first ayah of the visible pages (or pauses/resumes).</summary>
    [RelayCommand]
    private void PlayPage()
    {
        var rec = App.Instance.Recitation;
        if (rec.IsPlaying) { rec.TogglePause(); return; }
        var (su, a) = Idx.StartOf(RightPage);
        _quran.StartRecitationAt(su, a);
    }
}
