using CommunityToolkit.Mvvm.ComponentModel;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record OccasionItem(Occasion O, DateOnly Date, DateOnly Today)
{
    public string Emoji => O.Emoji;
    public string Name => O.Name;
    public string Subtitle => $"{Ui.Hijri(Date)} • {Ui.Date(Date)}";
    public string When => Date <= Today ? "الآن" : Occasions.InDays(Date.DayNumber - Today.DayNumber);
    public string Note => O.Note;
    public string Ref => O.Ref;
    public bool HasNote => O.Note.Length > 0;
    public bool HasRef => O.Ref.Length > 0;
}

/// <summary>المناسبات وصيام السنن: the next occasions with their hadith, today's sunnah fast and the year's voluntary fasts.</summary>
public sealed partial class OccasionsViewModel : ObservableObject
{
    [ObservableProperty] private string _heroTop = "";
    [ObservableProperty] private string _heroMain = "";
    [ObservableProperty] private string _heroSub = "";
    [ObservableProperty] private string? _fastToday;
    [ObservableProperty] private string _countText = "";
    [ObservableProperty] private IReadOnlyList<OccasionItem> _items = [];

    public string MonThuNote => Occasions.MonThuNote;
    public string MonThuRef => Occasions.MonThuRef;

    public OccasionsViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    public bool FastedToday
    {
        get => App.Instance.Tracker.Day(App.Instance.Today).Fast;
        set => App.Instance.Tracker.SetFast(App.Instance.Today, value);
    }

    public void Reload()
    {
        var today = App.Instance.Today;
        var adj = App.Instance.Settings.Current.HijriAdjustmentDays;
        Items = Occasions.All.Select(o => new OccasionItem(o, Occasions.Next(o, today, adj), today)).OrderBy(x => x.Date).ToList();
        var first = Items[0];
        var inProgress = first.Date <= today;
        HeroTop = inProgress ? "الآن" : "المناسبة القادمة";
        HeroMain = first.Name;
        HeroSub = inProgress ? Ui.Date(today) : $"{Occasions.InDays(first.Date.DayNumber - today.DayNumber)} • {Ui.Date(first.Date)}";
        FastToday = Occasions.SunnahFastOn(today, adj) is { } f ? $"اليوم: {f}" : null;

        // Voluntary fasts this Hijri year (outside Ramadan).
        var t = App.Instance.Tracker;
        var h = Ui.HijriOf(today);
        var count = 0;
        for (var d = Ui.FromHijri(h.Year, 1, 1); d <= today; d = d.AddDays(1))
            if (t.Day(d).Fast && Ui.HijriOf(d).Month != 9) count++;
        CountText = $"صمت هذا العام الهجري تطوعًا: {Ui.D(count)} {(count is >= 3 and <= 10 ? "أيام" : "يومًا")}";
        OnPropertyChanged(nameof(FastedToday));
    }
}
