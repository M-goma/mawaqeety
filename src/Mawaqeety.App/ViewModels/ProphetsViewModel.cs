using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed partial class ProphetListItem(Prophet prophet) : ObservableObject
{
    public Prophet Prophet { get; } = prophet;
    /// <summary>The recording in the chosen voice is on this PC.</summary>
    [ObservableProperty] private bool _isSaved;

    public string OrderText => QuranRepository.ArabicDigits(Prophet.Order);
    public string DisplayName => Prophet.Id == "muhammad" || Prophet.NameAr.StartsWith("محمد") ? "محمد عليه أفضل الصلاة والسلام" : $"{Prophet.NameAr} عليه السلام";
}

public sealed record AyatBlock(int Surah, int From, int To, string Text, string Reference, string Note);
public sealed record Paragraph(string Text);
public sealed record SectionView(string Heading, IReadOnlyList<Paragraph> Paragraphs);

public sealed partial class ProphetsViewModel : ObservableObject
{
    private static readonly QuranRepository Q = QuranRepository.Default;

    public IReadOnlyList<ProphetListItem> Prophets { get; } = Q.Prophets.Select(p => new ProphetListItem(p)).ToList();

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Subtitle), nameof(Summary), nameof(Sections), nameof(Ayat), nameof(Lessons), nameof(HasAyat), nameof(HasLessons))]
    private ProphetListItem? _selected;


    public string Title => Selected?.DisplayName ?? "";
    public string Subtitle => Selected?.Prophet.Title ?? "";
    public string Summary => Selected?.Prophet.Summary ?? "";

    public IReadOnlyList<SectionView> Sections => Selected?.Prophet.Sections
        .Select(s => new SectionView(s.Heading, s.Body.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(t => new Paragraph(t)).ToList()))
        .ToList() ?? [];

    public IReadOnlyList<AyatBlock> Ayat => Selected?.Prophet.Ayat.Select(a =>
    {
        var s = Q[a.Surah];
        var from = Math.Clamp(a.From, 1, s.Verses.Count);
        var to = Math.Clamp(a.To, from, s.Verses.Count);
        var text = string.Join(" ", Enumerable.Range(from, to - from + 1)
            .Select(i => $"{s.Verses[i - 1]} ﴿{QuranRepository.ArabicDigits(i)}﴾"));
        var reference = $"سورة {s.Name} ({QuranRepository.ArabicDigits(from)}{(to > from ? "–" + QuranRepository.ArabicDigits(to) : "")})";
        return new AyatBlock(a.Surah, from, to, text, reference, a.Note);
    }).ToList() ?? [];

    public IReadOnlyList<string> Lessons => Selected?.Prophet.Lessons ?? [];
    public bool HasAyat => Ayat.Count > 0;
    public bool HasLessons => Lessons.Count > 0;

    /// <summary>Opens the passage in the Qur'an reader.</summary>
    // ---------------- audio ----------------
    /// <summary>A prophet's story is being read (not another recording such as a battle's narration).</summary>
    public bool IsNarrating => App.Instance.Narration.IsSpeaking && !IsOtherRecording(App.Instance.Narration.CurrentId);
    private static bool IsOtherRecording(string? id) => id?.StartsWith("ghazwa-", StringComparison.Ordinal) == true;
    public bool IsNarrationPaused => IsNarrating && App.Instance.Narration.IsPaused;
    public string NarrateLabel => !IsNarrating ? "استمع إلى القصة" : IsNarrationPaused ? "متابعة" : "إيقاف مؤقت";
    public string NarrateGlyph => IsNarrating && !IsNarrationPaused ? "\uE769" : "\uE768";

    // ---------------- auto-play of the next story ----------------
    public bool Autoplay
    {
        get => App.Instance.Settings.Current.StoryAutoplay;
        set { App.Instance.Settings.Update(s => s.StoryAutoplay = value); OnPropertyChanged(); if (!value) CancelNext(); }
    }

    private DispatcherTimer? _nextTimer;
    private int _secondsLeft;
    [ObservableProperty] private bool _nextPending;
    [ObservableProperty] private string _nextText = "";

    private ProphetListItem? Neighbour(int step)
    {
        if (Selected is null) return null;
        var i = Prophets.ToList().IndexOf(Selected) + step;
        return i >= 0 && i < Prophets.Count ? Prophets[i] : null;
    }

    private void OnStoryFinished(string id)
    {
        if (!Autoplay || Neighbour(1) is not { } next || Selected?.Prophet.Id != id) return;
        _secondsLeft = 5;
        NextPending = true;
        NextText = $"القصة التالية: {next.DisplayName} بعد {QuranRepository.ArabicDigits(_secondsLeft)} ثوانٍ";
        _nextTimer?.Stop();
        _nextTimer = new DispatcherTimer(TimeSpan.FromSeconds(1), DispatcherPriority.Normal, (_, _) =>
        {
            _secondsLeft--;
            if (_secondsLeft > 0)
            {
                NextText = $"القصة التالية: {next.DisplayName} بعد {QuranRepository.ArabicDigits(_secondsLeft)} ثوانٍ";
                return;
            }
            CancelNext();
            Selected = next;
            Narrate();
        }, App.Instance.Dispatcher);
        _nextTimer.Start();
    }

    [RelayCommand]
    private void CancelNext()
    {
        _nextTimer?.Stop();
        _nextTimer = null;
        NextPending = false;
    }

    [RelayCommand]
    private void PlayNextNow()
    {
        if (Neighbour(1) is not { } next) return;
        CancelNext();
        Selected = next;
        Narrate();
    }

    // ---------------- offline download of the recorded stories ----------------
    public Services.DownloadManager Downloads => App.Instance.Downloads;
    [ObservableProperty] private bool _storiesDownloadOpen;
    [ObservableProperty] private string _storiesChoice = "Male";
    public string MaleSizeText => $"صوت رجل (نبيل) • {QuranRepository.ArabicDigits(StoryAudio.Default.SizeMb("Male"))} ميجابايت";
    public string FemaleSizeText => $"صوت امرأة (عرين) • {QuranRepository.ArabicDigits(StoryAudio.Default.SizeMb("Female"))} ميجابايت";
    public string BothSizeText => $"الصوتان معًا • {QuranRepository.ArabicDigits(StoryAudio.Default.SizeMb("Male") + StoryAudio.Default.SizeMb("Female"))} ميجابايت";
    [ObservableProperty] private string _storiesSavedText = "";
    public bool IsMaleChoice { get => StoriesChoice == "Male"; set { if (value) StoriesChoice = "Male"; } }
    public bool IsFemaleChoice { get => StoriesChoice == "Female"; set { if (value) StoriesChoice = "Female"; } }
    public bool IsBothChoice { get => StoriesChoice == "Both"; set { if (value) StoriesChoice = "Both"; } }

    partial void OnStoriesDownloadOpenChanged(bool value) { if (value) { StoriesChoice = NarrationVoice; RefreshSaved(); } }
    partial void OnStoriesChoiceChanged(string value)
    {
        OnPropertyChanged(nameof(IsMaleChoice));
        OnPropertyChanged(nameof(IsFemaleChoice));
        OnPropertyChanged(nameof(IsBothChoice));
    }

    private void RefreshSaved()
    {
        foreach (var p in Prophets) p.IsSaved = Services.DownloadManager.IsStorySaved(p.Prophet.Id, NarrationVoice);
        var mb = (int)(Services.DownloadManager.SavedStoriesBytes() / 1_000_000);
        StoriesSavedText = $"محفوظ: {QuranRepository.ArabicDigits(Services.DownloadManager.SavedStories("Male"))} قصة بصوت نبيل، "
            + $"{QuranRepository.ArabicDigits(Services.DownloadManager.SavedStories("Female"))} بصوت عرين ({QuranRepository.ArabicDigits(mb)} ميجابايت)";
    }

    [RelayCommand]
    private async Task DownloadAllStories()
    {
        StoriesDownloadOpen = false;
        await Downloads.DownloadStoriesAsync(StoriesChoice == "Both" ? ["Male", "Female"] : [StoriesChoice]);
    }

    [RelayCommand]
    private async Task DownloadThisStory()
    {
        if (Selected is null) return;
        await Downloads.DownloadStoriesAsync([NarrationVoice], [Selected.Prophet.Id]);
    }

    [RelayCommand] private void CancelStoriesDownload() => Downloads.CancelStories();

    [RelayCommand]
    private void DeleteStories()
    {
        if (System.Windows.MessageBox.Show("ستُحذف تسجيلات القصص من الجهاز، ويمكنك تنزيلها مرة أخرى في أي وقت.", "حذف القصص المحفوظة",
                System.Windows.MessageBoxButton.OKCancel, System.Windows.MessageBoxImage.Question) != System.Windows.MessageBoxResult.OK) return;
        Downloads.DeleteStories();
        RefreshSaved();
    }

    [RelayCommand] private void SeekBack() => App.Instance.Narration.Seek(-15);
    [RelayCommand] private void SeekForward() => App.Instance.Narration.Seek(15);
    [ObservableProperty] private string _audioStatus = "";

    public IReadOnlyList<KeyValuePair<string, string>> VoiceOptions { get; } =
        [new("Male", "صوت رجل (نبيل)"), new("Female", "صوت امرأة (عرين)")];

    public string NarrationVoice
    {
        get => App.Instance.Settings.Current.NarrationVoice;
        set
        {
            if (value == NarrationVoice) return;
            App.Instance.Settings.Update(s => s.NarrationVoice = value);
            OnPropertyChanged();
            RefreshSaved();
            AudioStatus = "";
            if (App.Instance.Narration.IsSpeaking)
            {
                App.Instance.Narration.Stop();
                Narrate(); // restart the story with the new voice
            }
        }
    }

    public ProphetsViewModel()
    {
        _selected = Prophets.FirstOrDefault();
        App.Instance.Narration.StateChanged += () => App.Instance.Dispatcher.BeginInvoke(() =>
        {
            OnPropertyChanged(nameof(IsNarrating));
            OnPropertyChanged(nameof(IsNarrationPaused));
            OnPropertyChanged(nameof(NarrateLabel));
            OnPropertyChanged(nameof(NarrateGlyph));
        });
        App.Instance.Downloads.StoriesChanged += RefreshSaved;
        RefreshSaved();
        App.Instance.Narration.Finished += id => App.Instance.Dispatcher.BeginInvoke(() => OnStoryFinished(id));
        App.Instance.Narration.SkipRequested += step => App.Instance.Dispatcher.BeginInvoke(() =>
        {
            if (Neighbour(step) is not { } p) return;
            CancelNext();
            Selected = p;
            Narrate();
        });
        App.Instance.Recitation.Error += msg => App.Instance.Dispatcher.BeginInvoke(() => AudioStatus = msg);
    }

    partial void OnSelectedChanged(ProphetListItem? value)
    {
        var current = App.Instance.Narration.CurrentId;
        if (current != value?.Prophet.Id && !IsOtherRecording(current)) App.Instance.Narration.Stop();
        AudioStatus = "";
    }

    [RelayCommand]
    private void Narrate()
    {
        var n = App.Instance.Narration;
        if (n.IsSpeaking && n.CurrentId == Selected?.Prophet.Id) { n.TogglePause(); return; }
        if (Selected is null) return;
        CancelNext();
        App.Instance.Recitation.Stop();
        var p = Selected.Prophet;
        var chunks = new List<string> { $"{Title}. {p.Title}. {p.Summary}" };
        foreach (var s in p.Sections)
        {
            chunks.Add(s.Heading + ".");
            chunks.AddRange(s.Body.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        }
        if (p.Lessons.Count > 0) chunks.Add("دروس وعبر. " + string.Join(" ", p.Lessons));
        AudioStatus = n.Play(p.Id, Title, chunks)
            ? ""
            : "لا يوجد صوت عربي مثبّت في Windows. ثبّته من: الإعدادات ← الوقت واللغة ← اللغة والمنطقة ← العربية ← خيارات اللغة ← الكلام، ثم أعد المحاولة.";
    }

    /// <summary>Recites a passage with the selected reciter.</summary>
    [RelayCommand]
    private void ReciteAyat(AyatBlock? a)
    {
        if (a is null) return;
        App.Instance.Narration.Stop();
        var rec = App.Instance.Recitation;
        rec.OnFinished = null;
        rec.Play(a.Surah, a.From, a.To);
    }

    [RelayCommand]
    private void StopAudio()
    {
        CancelNext();
        App.Instance.Narration.Stop();
        App.Instance.Recitation.Stop();
    }

    [RelayCommand]
    private void OpenInQuran(AyatBlock? a)
    {
        if (a is null || App.Instance.MainVm is not { } main) return;
        main.Page = Page.Quran;
        main.Quran.Open(a.Surah, a.From);
    }
}
