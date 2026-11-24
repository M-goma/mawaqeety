using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record ProphetListItem(Prophet Prophet)
{
    public string OrderText => QuranRepository.ArabicDigits(Prophet.Order);
    public string DisplayName => Prophet.Id == "muhammad" || Prophet.NameAr.StartsWith("محمد") ? "محمد ﷺ" : $"{Prophet.NameAr} عليه السلام";
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
    public bool IsNarrating => App.Instance.Narration.IsSpeaking;
    public string NarrateLabel => IsNarrating ? "إيقاف القراءة" : "استمع إلى القصة";
    [ObservableProperty] private string _audioStatus = "";

    public IReadOnlyList<KeyValuePair<string, string>> VoiceOptions { get; } =
        [new("Male", "صوت رجل"), new("Female", "صوت امرأة")];

    public string NarrationVoice
    {
        get => App.Instance.Settings.Current.NarrationVoice;
        set
        {
            if (value == NarrationVoice) return;
            App.Instance.Settings.Update(s => s.NarrationVoice = value);
            OnPropertyChanged();
            AudioStatus = App.Instance.Narration.ExactGenderAvailable
                ? ""
                : "لا يوجد في Windows صوت عربي بهذا النوع، فتم تعديل نبرة الصوت المتاح. لصوت أوضح: الإعدادات ← الوقت واللغة ← الكلام ← إضافة أصوات ← العربية.";
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
            OnPropertyChanged(nameof(NarrateLabel));
        });
        App.Instance.Recitation.Error += msg => App.Instance.Dispatcher.BeginInvoke(() => AudioStatus = msg);
    }

    partial void OnSelectedChanged(ProphetListItem? value)
    {
        App.Instance.Narration.Stop();
        AudioStatus = "";
    }

    [RelayCommand]
    private void Narrate()
    {
        var n = App.Instance.Narration;
        if (n.IsSpeaking) { n.Stop(); return; }
        if (Selected is null) return;
        App.Instance.Recitation.Stop();
        var p = Selected.Prophet;
        var chunks = new List<string> { $"{Title}. {p.Title}. {p.Summary}" };
        foreach (var s in p.Sections)
        {
            chunks.Add(s.Heading + ".");
            chunks.AddRange(s.Body.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        }
        if (p.Lessons.Count > 0) chunks.Add("دروس وعبر. " + string.Join(" ", p.Lessons));
        AudioStatus = n.Speak(chunks)
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
