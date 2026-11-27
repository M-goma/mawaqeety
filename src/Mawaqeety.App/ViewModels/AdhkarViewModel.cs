using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Calculation;
using Mawaqeety.Core.Models;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed partial class DhikrItem : ObservableObject
{
    public required string Text { get; init; }
    public bool IsQuran { get; init; }
    /// <summary>Section heading shown above the item (occasion duas).</summary>
    public string Heading { get; init; } = "";
    public bool HasHeading => Heading.Length > 0;
    public required string Source { get; init; }
    public string Virtue { get; init; } = "";
    public bool HasVirtue => Virtue.Length > 0;
    public int Count { get; init; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CounterText), nameof(Done), nameof(Progress))]
    private int _tapped;

    public bool Done => Tapped >= Count;
    public double Progress => Count == 0 ? 0 : Math.Min(1, Tapped / (double)Count);
    public string CounterText => Done ? "✓" : $"{QuranRepository.ArabicDigits(Count - Tapped)}";
    public string CountLabel => Count == 1 ? "مرة واحدة" : Count == 2 ? "مرتان" : $"{QuranRepository.ArabicDigits(Count)} مرات";
}

/// <summary>Morning and evening remembrances, chosen by the time of day, with a tap counter for each.</summary>
public sealed partial class AdhkarViewModel : ObservableObject
{
    private static readonly QuranRepository Q = QuranRepository.Default;
    public ObservableCollection<DhikrItem> Items { get; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Hint))]
    private bool _isMorning;

    /// <summary>Showing the occasion duas instead of the morning/evening adhkar.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Hint), nameof(IsMorningShown), nameof(IsEveningShown))]
    private bool _isDuas;

    public bool IsMorningShown => !IsDuas && IsMorning;
    public bool IsEveningShown => !IsDuas && !IsMorning;

    public IReadOnlyList<DuaGroup> DuaGroups => DuaBook.Default.Groups;
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title))]
    private DuaGroup? _group;

    public string Title => IsDuas ? $"{Group?.Emoji} {Group?.Title}" : IsMorning ? "أذكار الصباح" : "أذكار المساء";
    public string Hint => IsDuas
        ? "من كتاب «حصن المسلم». اختر المناسبة، واضغط على الدعاء ليُعدّ."
        : IsMorning
            ? "وقتها من الفجر إلى العصر. اضغط على الذكر بعد قوله ليُعدّ."
            : "وقتها من العصر إلى الليل. اضغط على الذكر بعد قوله ليُعدّ.";

    [ObservableProperty] private string _progressText = "";

    public AdhkarViewModel()
    {
        IsMorning = AutoMorning();
        Load();
    }

    /// <summary>Morning from Fajr until Asr (the current prayer period decides).</summary>
    private static bool AutoMorning()
    {
        try
        {
            var st = App.Instance.ComputeStatus(DateTimeOffset.Now);
            return st.Current is Prayer.Fajr or Prayer.Sunrise or Prayer.Dhuhr;
        }
        catch { return DateTime.Now.Hour is >= 4 and < 15; }
    }

    partial void OnIsMorningChanged(bool value) => Load();
    partial void OnIsDuasChanged(bool value) => Load();
    partial void OnGroupChanged(DuaGroup? value) { if (IsDuas) Load(); }

    [RelayCommand] private void ShowMorning() { IsDuas = false; IsMorning = true; Load(); }
    [RelayCommand] private void ShowEvening() { IsDuas = false; IsMorning = false; Load(); }
    [RelayCommand] private void ShowDuas() { Group ??= DuaGroups[0]; IsDuas = true; }
    [RelayCommand] private void PickGroup(DuaGroup? g) { if (g is not null) Group = g; }

    private void LoadDuas()
    {
        var g = Group ?? DuaGroups[0];
        foreach (var s in g.Sections)
        {
            var first = true;
            var many = s.Sources is { Count: > 0 } ? string.Join(" • ", s.Sources) : "";
            foreach (var d in s.Items)
            {
                var item = new DhikrItem
                {
                    Text = d.Text,
                    Source = d.Source ?? many,
                    Virtue = d.Virtue ?? "",
                    Count = Math.Max(1, d.Count),
                    Heading = first && g.Sections.Count > 1 ? s.Title : "",
                };
                first = false;
                item.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(DhikrItem.Done)) UpdateProgress(); };
                Items.Add(item);
            }
        }
        UpdateProgress();
    }

    private void Load()
    {
        Items.Clear();
        if (IsDuas) { LoadDuas(); return; }
        foreach (var d in Dhikr.All.Where(d => d.AvailableAt(IsMorning)))
        {
            string text;
            if (d.Quran.Count > 0)
            {
                var parts = new List<string>();
                var intro = d.TextFor(IsMorning);
                if (!string.IsNullOrEmpty(intro)) parts.Add(intro + ":");
                if (d.Basmala) parts.Add("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ");
                foreach (var q in d.Quran)
                {
                    var s = Q[q[0]];
                    for (var a = q[1]; a <= q[2] && a <= s.Verses.Count; a++)
                        parts.Add($"{s.Verses[a - 1]} ﴿{QuranRepository.ArabicDigits(a)}﴾");
                }
                text = string.Join(" ", parts);
            }
            else text = d.TextFor(IsMorning)!;
            var item = new DhikrItem { Text = text, IsQuran = d.Quran.Count > 0, Source = d.Source, Virtue = d.Virtue, Count = Math.Max(1, d.Count) };
            item.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(DhikrItem.Done)) UpdateProgress(); };
            Items.Add(item);
        }
        UpdateProgress();
    }

    private void UpdateProgress()
    {
        var done = Items.Count(i => i.Done);
        if (!IsDuas && done == Items.Count && Items.Count > 0 && Items.Any(i => i.Tapped > 0))
            App.Instance.Tracker.SetAdhkar(App.Instance.Today, morning: IsMorning); // counts toward today's statistics
        ProgressText = done == Items.Count && Items.Count > 0
            ? "أتممت الأذكار، تقبّل الله منك 🤍"
            : $"أتممت {QuranRepository.ArabicDigits(done)} من {QuranRepository.ArabicDigits(Items.Count)}";
    }

    [RelayCommand]
    private void Count(DhikrItem? d)
    {
        if (d is null || d.Done) return;
        d.Tapped++;
    }

    [RelayCommand]
    private void Reset()
    {
        foreach (var i in Items) i.Tapped = 0;
    }
}
