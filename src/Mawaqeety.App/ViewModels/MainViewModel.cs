using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Mawaqeety.App.ViewModels;

public enum Page { Dashboard, Times, Monthly, Quran, Adhkar, Tasbeeh, Stats, Qibla, Prophets, Hadith, Companions, Settings, About,
    Sabeel, Ramadan, WhiteDays, Occasions, Asma, Zakat, Khatma,
    Arbaeen, Fiqh, Asbab, Ghazawat, Nasab, CompanionsIslam, Calendar, Atlas }

public sealed partial class MainViewModel : ObservableObject
{
    public DashboardViewModel Dashboard { get; } = new();
    public TimesViewModel Times => _times ??= new TimesViewModel(Dashboard);
    private TimesViewModel? _times;
    public MonthlyViewModel Monthly { get; } = new();
    public SettingsViewModel Settings { get; } = new();
    public QuranViewModel Quran => _quran ??= new QuranViewModel();
    public ProphetsViewModel Prophets => _prophets ??= new ProphetsViewModel();
    private QuranViewModel? _quran;
    private ProphetsViewModel? _prophets;
    public AdhkarViewModel Adhkar => _adhkar ??= new AdhkarViewModel();
    public QiblaViewModel Qibla => _qibla ??= new QiblaViewModel();
    private AdhkarViewModel? _adhkar;
    private QiblaViewModel? _qibla;
    public TasbeehViewModel Tasbeeh => _tasbeeh ??= new TasbeehViewModel();
    public StatsViewModel Stats => _stats ??= new StatsViewModel();
    private TasbeehViewModel? _tasbeeh;
    private StatsViewModel? _stats;
    public HadithViewModel Hadith => _hadith ??= new HadithViewModel();
    public CompanionsViewModel Companions => _companions ??= new CompanionsViewModel();
    private HadithViewModel? _hadith;
    private CompanionsViewModel? _companions;
    public AboutViewModel About { get; } = new();
    public SabeelViewModel Sabeel => _sabeel ??= new SabeelViewModel();
    public RamadanViewModel Ramadan => _ramadan ??= new RamadanViewModel();
    public WhiteDaysViewModel WhiteDays => _whiteDays ??= new WhiteDaysViewModel();
    public OccasionsViewModel Occasions => _occasions ??= new OccasionsViewModel();
    public AsmaViewModel Asma => _asma ??= new AsmaViewModel();
    public ZakatViewModel Zakat => _zakat ??= new ZakatViewModel();
    public KhatmaViewModel Khatma => _khatma ??= new KhatmaViewModel();
    private SabeelViewModel? _sabeel;
    private RamadanViewModel? _ramadan;
    private WhiteDaysViewModel? _whiteDays;
    private OccasionsViewModel? _occasions;
    private AsmaViewModel? _asma;
    private ZakatViewModel? _zakat;
    private KhatmaViewModel? _khatma;
    public ArbaeenViewModel Arbaeen => _arbaeen ??= new ArbaeenViewModel();
    public FiqhViewModel Fiqh => _fiqh ??= new FiqhViewModel();
    public AsbabViewModel Asbab => _asbab ??= new AsbabViewModel();
    public GhazawatViewModel Ghazawat => _ghazawat ??= new GhazawatViewModel();
    public NasabViewModel Nasab => _nasab ??= new NasabViewModel();
    public CompanionsIslamViewModel CompanionsIslam => _companionsIslam ??= new CompanionsIslamViewModel();
    public CalendarViewModel Calendar => _calendar ??= new CalendarViewModel();
    public AtlasViewModel Atlas => _atlas ??= new AtlasViewModel();
    private ArbaeenViewModel? _arbaeen;
    private FiqhViewModel? _fiqh;
    private AsbabViewModel? _asbab;
    private GhazawatViewModel? _ghazawat;
    private NasabViewModel? _nasab;
    private CompanionsIslamViewModel? _companionsIslam;
    private CalendarViewModel? _calendar;
    private AtlasViewModel? _atlas;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentView), nameof(IsDashboard), nameof(IsTimes), nameof(IsMonthly), nameof(IsQuran), nameof(IsAdhkar), nameof(IsTasbeeh), nameof(IsStats), nameof(IsQibla), nameof(IsProphets), nameof(IsHadith), nameof(IsCompanions), nameof(IsSettings), nameof(IsAbout),
        nameof(IsSabeel), nameof(IsRamadan), nameof(IsWhiteDays), nameof(IsOccasions), nameof(IsAsma), nameof(IsZakat), nameof(IsKhatma),
        nameof(IsArbaeen), nameof(IsFiqh), nameof(IsAsbab), nameof(IsGhazawat), nameof(IsNasab), nameof(IsCompanionsIslam), nameof(IsCalendar), nameof(IsAtlas))]
    private Page _page = Page.Dashboard;

    public object CurrentView => Page switch
    {
        Page.Times => Times,
        Page.Monthly => Monthly,
        Page.Quran => Quran,
        Page.Adhkar => Adhkar,
        Page.Tasbeeh => Tasbeeh,
        Page.Stats => Stats,
        Page.Qibla => Qibla,
        Page.Prophets => Prophets,
        Page.Hadith => Hadith,
        Page.Companions => Companions,
        Page.Settings => Settings,
        Page.About => About,
        Page.Sabeel => Sabeel,
        Page.Ramadan => Ramadan,
        Page.WhiteDays => WhiteDays,
        Page.Occasions => Occasions,
        Page.Asma => Asma,
        Page.Zakat => Zakat,
        Page.Khatma => Khatma,
        Page.Arbaeen => Arbaeen,
        Page.Fiqh => Fiqh,
        Page.Asbab => Asbab,
        Page.Ghazawat => Ghazawat,
        Page.Nasab => Nasab,
        Page.CompanionsIslam => CompanionsIslam,
        Page.Calendar => Calendar,
        Page.Atlas => Atlas,
        _ => Dashboard,
    };

    public bool IsDashboard { get => Page == Page.Dashboard; set { if (value) Page = Page.Dashboard; } }
    public bool IsTimes { get => Page == Page.Times; set { if (value) Page = Page.Times; } }
    public bool IsMonthly { get => Page == Page.Monthly; set { if (value) { Page = Page.Monthly; Monthly.Reload(); } } }
    public bool IsQuran { get => Page == Page.Quran; set { if (value) Page = Page.Quran; } }
    public bool IsAdhkar { get => Page == Page.Adhkar; set { if (value) Page = Page.Adhkar; } }
    public bool IsTasbeeh { get => Page == Page.Tasbeeh; set { if (value) Page = Page.Tasbeeh; } }
    public bool IsStats { get => Page == Page.Stats; set { if (value) Page = Page.Stats; } }
    public bool IsQibla { get => Page == Page.Qibla; set { if (value) Page = Page.Qibla; } }
    public bool IsProphets { get => Page == Page.Prophets; set { if (value) Page = Page.Prophets; } }
    public bool IsHadith { get => Page == Page.Hadith; set { if (value) Page = Page.Hadith; } }
    public bool IsCompanions { get => Page == Page.Companions; set { if (value) Page = Page.Companions; } }
    public bool IsSettings { get => Page == Page.Settings; set { if (value) Page = Page.Settings; } }
    public bool IsAbout { get => Page == Page.About; set { if (value) Page = Page.About; } }
    public bool IsSabeel { get => Page == Page.Sabeel; set { if (value) Page = Page.Sabeel; } }
    public bool IsRamadan { get => Page == Page.Ramadan; set { if (value) Page = Page.Ramadan; } }
    public bool IsWhiteDays { get => Page == Page.WhiteDays; set { if (value) Page = Page.WhiteDays; } }
    public bool IsOccasions { get => Page == Page.Occasions; set { if (value) Page = Page.Occasions; } }
    public bool IsAsma { get => Page == Page.Asma; set { if (value) Page = Page.Asma; } }
    public bool IsZakat { get => Page == Page.Zakat; set { if (value) Page = Page.Zakat; } }
    /// <summary>The khatma page is opened from the Quran page (its sidebar entry stays the Quran's).</summary>
    public bool IsKhatma { get => Page == Page.Khatma; set { if (value) Page = Page.Khatma; } }
    public bool IsArbaeen { get => Page == Page.Arbaeen; set { if (value) Page = Page.Arbaeen; } }
    public bool IsFiqh { get => Page == Page.Fiqh; set { if (value) Page = Page.Fiqh; } }
    public bool IsAsbab { get => Page == Page.Asbab; set { if (value) Page = Page.Asbab; } }
    public bool IsGhazawat { get => Page == Page.Ghazawat; set { if (value) Page = Page.Ghazawat; } }
    public bool IsNasab { get => Page == Page.Nasab; set { if (value) Page = Page.Nasab; } }
    public bool IsCompanionsIslam { get => Page == Page.CompanionsIslam; set { if (value) Page = Page.CompanionsIslam; } }
    public bool IsAtlas { get => Page == Page.Atlas; set { if (value) Page = Page.Atlas; } }
    public bool IsCalendar { get => Page == Page.Calendar; set { if (value) { Page = Page.Calendar; Calendar.Reload(); } } }

    [RelayCommand]
    private void Navigate(Page page)
    {
        if (page == Page.Monthly) Monthly.Reload();
        Page = page;
    }

    public void OnWindowShown() => Dashboard.Start();
    public void OnWindowHidden() => Dashboard.Stop();

    public void Refresh()
    {
        Dashboard.Reload();
        Monthly.Reload();
        _ramadan?.Reload();
        _whiteDays?.Reload();
        _occasions?.Reload();
        _khatma?.Reload();
        _calendar?.Reload();
        _times?.Sunan.Reload();
    }
}

/// The prayer-times page: today's times and logging, using the home page's data.
public sealed class TimesViewModel(DashboardViewModel dash)
{
    public DashboardViewModel Dash { get; } = dash;
    public SunanViewModel Sunan { get; } = new();
}
