using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

public sealed record TasbeehOption(int Value, string Label, bool Selected);

/// <summary>Electronic tasbeeh: click (or press Space) to count; a target, an after-prayer sequence and a daily wird.</summary>
public sealed partial class TasbeehViewModel : ObservableObject
{
    public static readonly string[] Builtin =
    [
        "سُبْحَانَ اللهِ", "الْحَمْدُ لِلَّهِ", "اللهُ أَكْبَرُ", "لَا إِلَٰهَ إِلَّا اللهُ", "أَسْتَغْفِرُ اللهَ",
        "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ", "سُبْحَانَ اللهِ وَبِحَمْدِهِ",
    ];

    /// <summary>After each obligatory prayer: 33 × subhan Allah, 33 × al-hamdu lillah, 34 × Allahu akbar (Muslim).</summary>
    private static readonly (int Phrase, int Count)[] AfterPrayer = [(0, 33), (1, 33), (2, 34)];

    private static Mawaqeety.Core.Models.AppSettings S => App.Instance.Settings.Current;

    public TasbeehViewModel()
    {
        App.Instance.Tracker.Changed += () => App.Instance.Dispatcher.BeginInvoke(Refresh);
        Refresh();
    }

    private List<string> Phrases => [.. Builtin, .. S.TasbeehCustom];
    private int PhraseIndex => S.TasbeehTarget == -1 ? AfterPrayer[Math.Clamp(S.TasbeehStep, 0, 2)].Phrase : Math.Clamp(S.TasbeehPhrase, 0, Phrases.Count - 1);
    private int Target => S.TasbeehTarget == -1 ? AfterPrayer[Math.Clamp(S.TasbeehStep, 0, 2)].Count : S.TasbeehTarget;

    [ObservableProperty] private IReadOnlyList<TasbeehOption> _phraseOptions = [];
    [ObservableProperty] private IReadOnlyList<TasbeehOption> _targetOptions = [];
    [ObservableProperty] private string _phrase = "";
    [ObservableProperty] private string _countText = "";
    [ObservableProperty] private string _targetText = "";
    [ObservableProperty] private double _ring;
    [ObservableProperty] private string _stepText = "";
    [ObservableProperty] private string _todayText = "";
    [ObservableProperty] private string _monthText = "";
    [ObservableProperty] private string _totalText = "";
    [ObservableProperty] private string _wirdText = "";
    [ObservableProperty] private double _wirdProgress;
    [ObservableProperty] private bool _wirdDone;
    [ObservableProperty] private string _newPhrase = "";

    public int WirdGoal
    {
        get => S.WirdGoal;
        set { App.Instance.Settings.Update(s => s.WirdGoal = Math.Max(0, value)); OnPropertyChanged(); Refresh(); }
    }

    private void Refresh()
    {
        var phrases = Phrases;
        PhraseOptions = phrases.Select((p, i) => new TasbeehOption(i, p, S.TasbeehTarget != -1 && i == PhraseIndex)).ToList();
        TargetOptions = new[] { (33, "٣٣"), (100, "١٠٠"), (0, "حر"), (-1, "بعد الصلاة ٣٣+٣٣+٣٤") }
            .Select(t => new TasbeehOption(t.Item1, t.Item2, S.TasbeehTarget == t.Item1)).ToList();
        Phrase = phrases[PhraseIndex];
        var target = Target;
        CountText = QuranRepository.ArabicDigits(S.TasbeehCount);
        TargetText = target > 0 ? $"من {QuranRepository.ArabicDigits(target)}" : "عدّ حر";
        Ring = target > 0 ? S.TasbeehCount / (double)target : S.TasbeehCount % 100 / 100.0;
        StepText = S.TasbeehTarget == -1 ? $"الخطوة {QuranRepository.ArabicDigits(S.TasbeehStep + 1)} من ٣ • تسبيح ما بعد الصلاة" : "";
        var t = App.Instance.Tracker;
        var today = App.Instance.Today;
        var n = t.Day(today).Tasbeeh;
        TodayText = QuranRepository.ArabicDigits(n);
        MonthText = QuranRepository.ArabicDigits(t.TasbeehBetween(new DateOnly(today.Year, today.Month, 1), today));
        TotalText = QuranRepository.ArabicDigits(t.TasbeehBetween(DateOnly.MinValue, today));
        var goal = S.WirdGoal;
        WirdText = goal > 0 ? $"{QuranRepository.ArabicDigits(n)} / {QuranRepository.ArabicDigits(goal)}" : "غير محدد";
        WirdProgress = goal > 0 ? Math.Min(1, n / (double)goal) : 0;
        WirdDone = goal > 0 && n >= goal;
    }

    [RelayCommand]
    public void Count()
    {
        var target = Target;
        var next = S.TasbeehCount + 1;
        App.Instance.Settings.Update(s =>
        {
            if (target > 0 && next >= target)
            {
                s.TasbeehCount = 0;
                if (s.TasbeehTarget == -1) s.TasbeehStep = (s.TasbeehStep + 1) % 3;
            }
            else s.TasbeehCount = next;
        });
        if (target > 0 && next >= target) System.Media.SystemSounds.Asterisk.Play(); // round complete
        App.Instance.Tracker.AddTasbeeh(App.Instance.Today); // refreshes the view through Changed
    }

    [RelayCommand]
    private void Reset()
    {
        App.Instance.Settings.Update(s => { s.TasbeehCount = 0; s.TasbeehStep = 0; });
        Refresh();
    }

    [RelayCommand]
    private void SelectPhrase(int index)
    {
        App.Instance.Settings.Update(s => { s.TasbeehPhrase = index; s.TasbeehCount = 0; if (s.TasbeehTarget == -1) s.TasbeehTarget = 33; });
        Refresh();
    }

    [RelayCommand]
    private void SelectTarget(int value)
    {
        App.Instance.Settings.Update(s => { s.TasbeehTarget = value; s.TasbeehCount = 0; s.TasbeehStep = 0; });
        Refresh();
    }

    [RelayCommand]
    private void AddPhrase()
    {
        var text = NewPhrase.Trim();
        if (text.Length == 0) return;
        App.Instance.Settings.Update(s =>
        {
            s.TasbeehCustom = [.. s.TasbeehCustom, text];
            s.TasbeehPhrase = Builtin.Length + s.TasbeehCustom.Count - 1;
            if (s.TasbeehTarget == -1) s.TasbeehTarget = 33;
            s.TasbeehCount = 0;
        });
        NewPhrase = "";
        Refresh();
    }

    /// <summary>Removes a custom phrase (built-in ones stay).</summary>
    [RelayCommand]
    private void RemovePhrase(int index)
    {
        if (index < Builtin.Length) return;
        App.Instance.Settings.Update(s => { s.TasbeehCustom = s.TasbeehCustom.Where((_, i) => i != index - Builtin.Length).ToList(); s.TasbeehPhrase = 0; });
        Refresh();
    }
}
