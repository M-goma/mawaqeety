using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;
using Mawaqeety.Core.Tracking;

namespace Mawaqeety.App.ViewModels;

public sealed record PlanOption(int Days, string Label, bool Selected);

/// <summary>ورد القرآن والختمة: the plan, today's wird and the progress (pages are counted when shown in the Mushaf).</summary>
public sealed partial class KhatmaViewModel : ObservableObject
{
    [ObservableProperty] private bool _active;
    [ObservableProperty] private string _heroTop = "";
    [ObservableProperty] private string _heroMain = "";
    [ObservableProperty] private string _heroSub = "";
    [ObservableProperty] private double _progress;
    [ObservableProperty] private string _continueText = "";
    [ObservableProperty] private string _plansTitle = "";
    [ObservableProperty] private IReadOnlyList<PlanOption> _plans = [];
    [ObservableProperty] private string _doneText = "";
    [ObservableProperty] private string _todayText = "";
    [ObservableProperty] private string _weekText = "";
    // The «وردك اليوم» card on the Quran page
    [ObservableProperty] private string _wirdTitle = "";
    [ObservableProperty] private string _wirdCount = "";
    [ObservableProperty] private string _wirdSub = "";

    public KhatmaViewModel()
    {
        App.Instance.Settings.Changed += _ => App.Instance.Dispatcher.BeginInvoke(Reload);
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    private int NextPage => Math.Clamp(App.Instance.Settings.Current.KhatmaPage + 1, 1, Khatma.Pages);

    public void Reload()
    {
        var s = App.Instance.Settings.Current;
        var today = App.Instance.Today;
        Active = s.KhatmaDays > 0;
        var daily = Khatma.Daily(s);
        var read = Khatma.PagesToday(s, today);
        Progress = s.KhatmaPage / (double)Khatma.Pages;
        if (Active)
        {
            HeroTop = $"ختمة في {Khatma.PlanLabel(s.KhatmaDays)} • اليوم {Ui.D(Khatma.Day(s, today))}";
            HeroMain = $"وصلت إلى صفحة {Ui.D(s.KhatmaPage)}";
            HeroSub = $"وردك اليومي {Occasions.Pages(daily)} • المطلوب حتى اليوم: صفحة {Ui.D(Khatma.Target(s, today))}";
        }
        else
        {
            HeroTop = "";
            HeroMain = "";
            HeroSub = "اختر مدة الختمة، فنحسب ورد كل يوم، ونتابع تقدّمك تلقائيًا من صفحات المصحف التي تقرؤها.";
        }
        ContinueText = $"أكمل من صفحة {Ui.D(NextPage)}";
        PlansTitle = Active ? "تغيير المدة (يبدأ ختمة جديدة)" : "مدة الختمة";
        Plans = Khatma.Plans.Select(d => new PlanOption(d, $"{Khatma.PlanLabel(d)} • {Occasions.Pages(Khatma.DailyFor(d))}", s.KhatmaDays == d)).ToList();
        var week = 0;
        for (var i = 0; i < 7; i++) week += App.Instance.Tracker.Day(today.AddDays(-i)).Pages;
        DoneText = Ui.D(s.KhatmaDone);
        TodayText = Ui.D(read);
        WeekText = Ui.D(week);

        if (Active)
        {
            var left = Khatma.Behind(s, today);
            WirdTitle = "وردك اليوم";
            WirdCount = $"{Ui.D(read)} / {Ui.D(daily)}";
            WirdSub = left == 0 ? $"أنت على الخطة • الختمة {Ui.D((int)Math.Round(s.KhatmaPage * 100.0 / Khatma.Pages))}٪" : $"باقي {Occasions.Pages(left)} لتلحق بخطتك";
        }
        else
        {
            WirdTitle = "ورد القرآن والختمة";
            WirdCount = read > 0 ? Ui.D(read) + " اليوم" : "";
            WirdSub = "حدّد مدة ختمتك ونحسب لك ورد كل يوم";
        }
    }

    [RelayCommand]
    private void StartPlan(int days)
    {
        var s = App.Instance.Settings.Current;
        if (s.KhatmaDays == days) { Reload(); return; }
        if (s.KhatmaDays > 0 && s.KhatmaPage > 0 &&
            MessageBox.Show($"ستبدأ ختمة جديدة في {Khatma.PlanLabel(days)} من الصفحة الأولى.", "ختمة جديدة؟",
                MessageBoxButton.OKCancel, MessageBoxImage.Question) != MessageBoxResult.OK)
        {
            Reload();
            return;
        }
        Start(days);
    }

    /// <summary>Starts a plan without asking (also used by the smoke test).</summary>
    public void Start(int days) => App.Instance.Settings.Update(s => Khatma.Start(s, days, App.Instance.Today));

    [RelayCommand] private static void Stop() => App.Instance.Settings.Update(Khatma.Stop);

    [RelayCommand] private void Continue() => App.Instance.OpenMushaf(NextPage);

    [RelayCommand] private static void Open() { if (App.Instance.MainVm is { } m) m.Page = Page.Khatma; }

    [RelayCommand] private static void BackToMushaf() { if (App.Instance.MainVm is { } m) m.Page = Page.Quran; }
}

public sealed partial class SunnahItem(Sunnah s) : ObservableObject
{
    public Sunnah S { get; } = s;
    public string Label => S.Label();
    public string Detail => S.Detail();

    public bool Done
    {
        get => App.Instance.Tracker.Day(App.Instance.Today).Did(S);
        set => App.Instance.Tracker.SetSunnah(App.Instance.Today, S, value);
    }

    public void Refresh() => OnPropertyChanged(nameof(Done));
}

/// <summary>السنن والنوافل: today's confirmed sunnahs (the card on the prayer-times page).</summary>
public sealed partial class SunanViewModel : ObservableObject
{
    public IReadOnlyList<SunnahItem> Items { get; } = Enum.GetValues<Sunnah>().Select(s => new SunnahItem(s)).ToList();
    [ObservableProperty] private string _countText = "";
    public string Hadith => "«ما من عبدٍ مسلمٍ يصلّي لله كل يومٍ ثنتي عشرة ركعةً تطوعًا غير فريضة إلا بنى الله له بيتًا في الجنة» — صحيح مسلم ٧٢٨";

    public SunanViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    public void Reload()
    {
        foreach (var i in Items) i.Refresh();
        CountText = $"{Ui.D(App.Instance.Tracker.Day(App.Instance.Today).SunanDone)} / {Ui.D(Items.Count)}";
    }
}
