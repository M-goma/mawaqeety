using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record ProphetListItem(Prophet Prophet)
{
    public string OrderText => QuranRepository.ArabicDigits(Prophet.Order);
    public string DisplayName => Prophet.Id == "muhammad" || Prophet.NameAr.StartsWith("محمد") ? "محمد ﷺ" : $"{Prophet.NameAr} عليه السلام";
}

public sealed record AyatBlock(int Surah, int From, string Text, string Reference, string Note);
public sealed record Paragraph(string Text);
public sealed record SectionView(string Heading, IReadOnlyList<Paragraph> Paragraphs);

public sealed partial class ProphetsViewModel : ObservableObject
{
    private static readonly QuranRepository Q = QuranRepository.Default;

    public IReadOnlyList<ProphetListItem> Prophets { get; } = Q.Prophets.Select(p => new ProphetListItem(p)).ToList();

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Subtitle), nameof(Summary), nameof(Sections), nameof(Ayat), nameof(Lessons), nameof(HasAyat), nameof(HasLessons))]
    private ProphetListItem? _selected;

    public ProphetsViewModel() => _selected = Prophets.FirstOrDefault();

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
        return new AyatBlock(a.Surah, from, text, reference, a.Note);
    }).ToList() ?? [];

    public IReadOnlyList<string> Lessons => Selected?.Prophet.Lessons ?? [];
    public bool HasAyat => Ayat.Count > 0;
    public bool HasLessons => Lessons.Count > 0;

    /// <summary>Opens the passage in the Qur'an reader.</summary>
    [RelayCommand]
    private void OpenInQuran(AyatBlock? a)
    {
        if (a is null || App.Instance.MainVm is not { } main) return;
        main.Page = Page.Quran;
        main.Quran.Open(a.Surah, a.From);
    }
}
