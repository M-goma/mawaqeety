using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record AsmaItem(int Index, BeautifulName N)
{
    public string Number => Ui.D(Index + 1);
    public string Name => N.Name;
    public string Meaning => N.Meaning;
    public bool Disputed => N.Disputed;
}

/// <summary>أسماء الله الحسنى: the name of the day, search, the grid and the selected name's meaning.</summary>
public sealed partial class AsmaViewModel : ObservableObject
{
    private readonly List<AsmaItem> _all = AsmaAlHusna.All.Select((n, i) => new AsmaItem(i, n)).ToList();

    [ObservableProperty] private string _query = "";
    [ObservableProperty] private IReadOnlyList<AsmaItem> _items;
    [ObservableProperty] private AsmaItem _selected;

    public AsmaItem OfDay { get; }
    public string Notes => AsmaAlHusna.Notes;
    public string DisputedNote => AsmaAlHusna.DisputedNote;

    public AsmaViewModel()
    {
        OfDay = _all[AsmaAlHusna.OfDay(App.Instance.Today)];
        _items = _all;
        _selected = OfDay;
    }

    partial void OnQueryChanged(string value)
    {
        var q = QuranRepository.Normalize(value);
        Items = q.Length == 0 ? _all
            : _all.Where(x => QuranRepository.Normalize(x.Name).Contains(q, StringComparison.Ordinal) || QuranRepository.Normalize(x.Meaning).Contains(q, StringComparison.Ordinal)).ToList();
    }

    [RelayCommand] private void Select(AsmaItem? x) { if (x is not null) Selected = x; }
}

/// <summary>حاسبة الزكاة: money, gold, silver and trade goods; the prices are kept in the settings.</summary>
public sealed partial class ZakatViewModel : ObservableObject
{
    [ObservableProperty] private string _cash = "";
    [ObservableProperty] private string _owed = "";
    [ObservableProperty] private string _trade = "";
    [ObservableProperty] private string _gold24 = "";
    [ObservableProperty] private string _gold21 = "";
    [ObservableProperty] private string _gold18 = "";
    [ObservableProperty] private string _silver = "";
    [ObservableProperty] private string _debts = "";
    [ObservableProperty] private string _goldPrice;
    [ObservableProperty] private string _silverPrice;

    [ObservableProperty] private string _heroLabel = "";
    [ObservableProperty] private string _heroAmount = "—";
    [ObservableProperty] private string _heroSub = "";

    public ZakatViewModel()
    {
        var s = App.Instance.Settings.Current;
        _goldPrice = Fmt(s.GoldPrice);
        _silverPrice = Fmt(s.SilverPrice);
        Recalc();
    }

    private static string Fmt(double v) => v > 0 ? v.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture) : "";

    public bool BySilver
    {
        get => App.Instance.Settings.Current.NisabSilver;
        set { App.Instance.Settings.Update(s => s.NisabSilver = value); OnPropertyChanged(); Recalc(); }
    }

    partial void OnCashChanged(string value) => Recalc();
    partial void OnOwedChanged(string value) => Recalc();
    partial void OnTradeChanged(string value) => Recalc();
    partial void OnGold24Changed(string value) => Recalc();
    partial void OnGold21Changed(string value) => Recalc();
    partial void OnGold18Changed(string value) => Recalc();
    partial void OnSilverChanged(string value) => Recalc();
    partial void OnDebtsChanged(string value) => Recalc();
    partial void OnGoldPriceChanged(string value) { App.Instance.Settings.Update(s => s.GoldPrice = Zakat.Parse(value)); Recalc(); }
    partial void OnSilverPriceChanged(string value) { App.Instance.Settings.Update(s => s.SilverPrice = Zakat.Parse(value)); Recalc(); }

    private void Recalc()
    {
        var p = Zakat.Parse;
        var r = Zakat.Compute(new Zakat.Input(p(Cash), p(Owed), p(Trade), p(Gold24), p(Gold21), p(Gold18), p(Silver), p(Debts)),
            p(GoldPrice), p(SilverPrice), BySilver);
        HeroLabel = !r.PricesKnown ? $"أدخل سعر جرام {(BySilver ? "الفضة" : "الذهب عيار ٢٤")} أولًا" : r.Due ? "الزكاة الواجبة" : "لم يبلغ مالك النصاب";
        HeroAmount = r.Due ? Zakat.Money(r.Amount) : "—";
        HeroSub = r.PricesKnown ? $"مالك الزكوي: {Zakat.Money(Math.Max(0, r.Total))} • النصاب: {Zakat.Money(r.Nisab)}" : "";
    }
}
