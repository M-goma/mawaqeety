using System.Diagnostics;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

// Pages ported from the mobile app's «المزيد» section: الأربعون النووية، فقه العبادات، أسباب النزول، غزوات النبي ﷺ،
// النسب الشريف، كيف أسلم الصحابة، التقويم الميلادي، أطلس قصص الأنبياء.

public static class Links
{
    public static void Open(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) return;
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (Exception ex) { App.Instance.Log.Warn($"Opening {url} failed", ex); }
    }

    public static void Copy(string text)
    {
        try { Clipboard.SetText(text); } catch { /* clipboard busy */ }
    }

    /// <summary>A Qur'an passage as shown on the prophets' page: Uthmani text with ayah numbers, and its reference.</summary>
    public static AyatBlock Ayat(int surah, int from, int to, string note, int maxShown = int.MaxValue)
    {
        var s = QuranRepository.Default[surah];
        from = Math.Clamp(from, 1, s.Verses.Count);
        to = Math.Clamp(to, from, s.Verses.Count);
        var shown = Enumerable.Range(from, Math.Min(to - from + 1, maxShown)).Select(i => $"{s.Verses[i - 1]} ﴿{Ui.D(i)}﴾");
        var text = string.Join(" ", shown) + (to - from + 1 > maxShown ? " …" : "");
        var reference = $"سورة {s.Name} ({Ui.D(from)}{(to > from ? "–" + Ui.D(to) : "")})";
        return new AyatBlock(surah, from, to, text, reference, note);
    }

    public static void OpenInQuran(AyatBlock? a)
    {
        if (a is null || App.Instance.MainVm is not { } main) return;
        main.Page = Page.Quran;
        main.Quran.Open(a.Surah, a.From);
    }

    public static void Recite(AyatBlock? a)
    {
        if (a is null) return;
        App.Instance.Narration.Stop();
        var rec = App.Instance.Recitation;
        rec.OnFinished = null;
        rec.Play(a.Surah, a.From, a.To);
    }
}

/// <summary>A source with a link (shown as a small chip that opens the page).</summary>
public sealed record LinkItem(string Label, string Url)
{
    public static LinkItem From(SourceLink s) => new(s.Label, s.Url);
}

/// <summary>A hadith of the bundled Sahihs, shown under a button and loaded only when opened.</summary>
public sealed partial class HadithLink(string label, Func<Hadith?> resolve) : ObservableObject
{
    public string Label { get; } = label;
    [ObservableProperty] private bool _isOpen;
    [ObservableProperty] private bool _loading;
    [ObservableProperty] private string _text = "";
    [ObservableProperty] private string _reference = "";
    private bool _loaded;

    [RelayCommand]
    private async Task Toggle()
    {
        IsOpen = !IsOpen;
        if (IsOpen) await LoadAsync();
    }

    public async Task LoadAsync()
    {
        if (_loaded || Loading) return;
        Loading = true;
        Hadith? h = null;
        try { h = await Task.Run(resolve); }
        catch (Exception ex) { App.Instance.Log.Warn("Loading a hadith failed", ex); }
        Loading = false;
        _loaded = true;
        if (h is null) { Text = "تعذّر العثور على الحديث في نسخة التطبيق."; return; }
        Text = App.Instance.Settings.Current.HadithFull || !h.HasMatn ? h.Text : h.Matn;
        Reference = $"{h.Collection.Name} • {Ui.D(h.Number)} • {h.Collection.BookName(h.Book)}";
    }

    [RelayCommand]
    private void Copy() { if (Text.Length > 0) Links.Copy($"{Text}\n\n[{Reference}]"); }
}

// ============================================================ الأربعون النووية

public sealed partial class ArbaeenItem(ArbaeenHadith h, bool memorized) : ObservableObject
{
    public ArbaeenHadith H { get; } = h;
    public string NumberText => Ui.D(H.Number);
    [ObservableProperty] private bool _isMemorized = memorized;
}

/// <summary>An-Nawawi's forty hadiths with his takhrij, links to the two Sahihs, Ibn Rajab's benefits and a «memorised» tick.</summary>
public sealed partial class ArbaeenViewModel : ObservableObject
{
    public ArbaeenBook Book => ArbaeenBook.Default;
    public IReadOnlyList<ArbaeenItem> Items { get; }
    public string AboutText => string.Join("\n", Book.About.Select(a => $"«{a}»"));
    public string AboutSourceText => "— " + Book.AboutSource;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HeaderTitle), nameof(Narrator), nameof(Grade), nameof(HasGrade), nameof(Extra), nameof(HasExtra),
        nameof(HasExtraTakhrij), nameof(Note), nameof(HasNote), nameof(IsnadNote), nameof(HasIsnadNote), nameof(SahihLinks),
        nameof(HasSahih), nameof(SahihHeading), nameof(Benefits), nameof(HasBenefits), nameof(HasBenefitsUrl))]
    [NotifyCanExecuteChangedFor(nameof(PrevCommand), nameof(NextCommand))]
    private ArbaeenItem? _selected;

    public string HeaderTitle => Selected is { } s ? $"الحديث {ArbaeenBook.Ordinal(s.H.Number)}" : "";
    public string Narrator => Selected is { } s ? $"رواية {s.H.Narrator}" : "";
    public string Grade => Selected?.H.Grade is { } g ? $"درجته عند النووي: {g}" : "";
    public bool HasGrade => Selected?.H.Grade is not null;
    public ArbaeenExtra? Extra => Selected?.H.Extra;
    public bool HasExtra => Extra is not null;
    public bool HasExtraTakhrij => !string.IsNullOrEmpty(Extra?.Takhrij);
    public string Note => Selected?.H.Note ?? "";
    public bool HasNote => Note.Length > 0;
    public string IsnadNote => Selected?.H.IsnadNote is { } n ? $"قال ابن رجب: «{n}»." : "";
    public bool HasIsnadNote => IsnadNote.Length > 0;
    public IReadOnlyList<HadithLink> SahihLinks { get; private set; } = [];
    public bool HasSahih => SahihLinks.Count > 0;
    public string SahihHeading => Selected?.H.Sahih is { Count: > 0 } ? "في الصحيحين" : "أصله في الصحيحين";
    public IReadOnlyList<string> Benefits => Selected?.H.Benefits ?? [];
    public bool HasBenefits => Benefits.Count > 0;
    public bool HasBenefitsUrl => !string.IsNullOrEmpty(Selected?.H.BenefitsUrl);

    [ObservableProperty] private string _memorizedText = "";
    [ObservableProperty] private double _memorizedProgress;
    [ObservableProperty] private string _memorizedPercent = "";

    public ArbaeenViewModel()
    {
        var done = App.Instance.Settings.Current.ArbaeenMemorized.ToHashSet();
        Items = Book.Hadiths.Select(h => new ArbaeenItem(h, done.Contains(h.Number))).ToList();
        foreach (var i in Items) i.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(ArbaeenItem.IsMemorized)) SaveMemorized(); };
        UpdateProgress();
        Selected = Items[0];
    }

    partial void OnSelectedChanged(ArbaeenItem? value)
    {
        SahihLinks = value is null ? [] : (value.H.Sahih ?? []).Concat(value.H.Related ?? [])
            .Select(r => new HadithLink($"{r.Name} • {Ui.D(r.Number)}", r.Resolve)).ToList();
    }

    private void SaveMemorized()
    {
        var list = Items.Where(i => i.IsMemorized).Select(i => i.H.Number).ToList();
        App.Instance.Settings.Update(s => s.ArbaeenMemorized = list);
        UpdateProgress();
    }

    private void UpdateProgress()
    {
        var n = Items.Count(i => i.IsMemorized);
        MemorizedText = $"حفظت {Ui.D(n)} من {Ui.D(Items.Count)}";
        MemorizedProgress = Items.Count == 0 ? 0 : 100.0 * n / Items.Count;
        MemorizedPercent = $"{Ui.D((int)Math.Round(MemorizedProgress))}٪";
    }

    private int Index => Selected is null ? -1 : Items.ToList().IndexOf(Selected);
    private bool CanPrev() => Index > 0;
    private bool CanNext() => Index >= 0 && Index < Items.Count - 1;
    [RelayCommand(CanExecute = nameof(CanPrev))] private void Prev() => Selected = Items[Index - 1];
    [RelayCommand(CanExecute = nameof(CanNext))] private void Next() => Selected = Items[Index + 1];

    [RelayCommand]
    private void Copy()
    {
        if (Selected is { } s) Links.Copy($"{s.H.CopyText}\n— الأربعون النووية، الحديث {Ui.D(s.H.Number)}");
    }

    [RelayCommand] private void OpenBenefits() => Links.Open(Selected?.H.BenefitsUrl);
}

// ============================================================ فقه العبادات المختصر

public sealed partial class TopicChip(string label, string? topic) : ObservableObject
{
    public string Label { get; } = label;
    public string? Topic { get; } = topic;
    [ObservableProperty] private bool _isSelected;
}

public sealed record FiqhAnswerView(FiqhAnswer A)
{
    /// <summary>A colour per source (as in the mobile app): إسلام ويب green, دار الإفتاء gold, الأزهر blue.</summary>
    public string Color => A.Source switch { "إسلام ويب" => "#12A372", "دار الإفتاء المصرية" => "#C9A227", _ => "#4A86C8" };
    public string SoftColor => "#29" + Color[1..];
    public string Source => A.Source;
    public string Text => $"«{A.Text}»";
    public string Ref => Ui.D(A.Ref);
    public string Url => A.Url;
}

public sealed record FiqhItemView(FiqhItem I)
{
    public string Header => $"{I.Topic} • {I.Sub}";
    public string Question => I.Question;
    public bool Khilaf => I.Khilaf;
    public IReadOnlyList<FiqhAnswerView> Answers { get; } = I.Answers.Select(a => new FiqhAnswerView(a)).ToList();
}

/// <summary>Short questions on worship with excerpts quoted from published fatwas, each with its source and link.</summary>
public sealed partial class FiqhViewModel : ObservableObject
{
    public FiqhBook Book => FiqhBook.Default;
    public IReadOnlyList<TopicChip> Topics { get; }
    private readonly IReadOnlyList<FiqhItemView> _all;
    [ObservableProperty] private IReadOnlyList<FiqhItemView> _items = [];
    [ObservableProperty] private string _query = "";
    [ObservableProperty] private string _footer = "";
    public string HeroTitle => $"{Ui.D(Book.Items.Count)} مسألة في الطهارة والصلاة والصيام والزكاة والحج";

    public FiqhViewModel()
    {
        _all = Book.Items.Select(i => new FiqhItemView(i)).ToList();
        Topics = new[] { new TopicChip("الكل", null) }.Concat(Book.Topics.Select(t => new TopicChip(t, t))).ToList();
        Topics[0].IsSelected = true;
        foreach (var t in Topics) t.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(TopicChip.IsSelected) && t.IsSelected) Refilter(); };
        Refilter();
    }

    partial void OnQueryChanged(string value) => Refilter();

    [RelayCommand] private void ClearQuery() => Query = "";
    [RelayCommand] private static void OpenUrl(string? url) => Links.Open(url);

    private void Refilter()
    {
        var topic = Topics.FirstOrDefault(t => t.IsSelected)?.Topic;
        Items = _all.Where(v => (topic is null || v.I.Topic == topic) && (string.IsNullOrWhiteSpace(Query) || v.I.Matches(Query))).ToList();
        Footer = Items.Count == 0
            ? "لا توجد مسألة مطابقة، جرّب كلمة أخرى."
            : $"جُمعت في {Ui.D(Book.Collected.Replace('-', '/'))} من: {string.Join("، ", Book.Sources.Select(s => s.Name))}.";
    }
}

// ============================================================ أسباب النزول والمكي والمدني

public sealed record SababView(Sabab S)
{
    public string Excerpt => S.Excerpt;
    public string Ref => S.Ref;
    public HadithLink Full { get; } = new("الحديث كاملًا", S.Hadith);
}

public sealed record AsbabGroup(string AyahLabel, AyatBlock Ayat, IReadOnlyList<SababView> Narrations);

public sealed record AsbabSurahItem(Surah Surah, IReadOnlyList<Sabab> Asbab)
{
    public string NumberText => Ui.D(Surah.Number);
    public string Name => $"سورة {Surah.Name}";
    public string TypeText => Surah.Meccan ? "مكية" : "مدنية";
    public bool IsMeccan => Surah.Meccan;
    public bool HasAsbab => Asbab.Count > 0;
    public string Subtitle => Asbab.Count == 0 ? AsbabViewModel.AyatCount(Surah.Verses.Count)
        : $"{AsbabViewModel.AyatCount(Surah.Verses.Count)} • {AsbabViewModel.Narrations(Asbab.Count)} في سبب النزول";
}

/// <summary>Every surah with its Makki/Madani type and the sahih occasions of revelation narrated in the two Sahihs.</summary>
public sealed partial class AsbabViewModel : ObservableObject
{
    public const string NoteText = "اقتصرنا هنا على روايات صحيحَي البخاري ومسلم التي تصرّح بأن الآية نزلت في واقعة بعينها "
        + "(«فنزلت»، «فأنزل الله»، «نزلت في…») وتذكر الآية نفسها. وقد يصحّ للآية سبب آخر في غير الصحيحين، "
        + "وقد تتعدد أسباب الآية الواحدة، ويرى بعض العلماء أن قول الصحابي «نزلت في كذا» قد يُراد به التفسير لا السبب. "
        + "وتصنيف السور إلى مكية ومدنية على ما في مصحف المدينة النبوية (مجمع الملك فهد)، وفي بعض السور خلاف بين العلماء.";
    public string Note => NoteText;

    public static string AyatCount(int n) => n switch
    {
        1 => "آية واحدة", 2 => "آيتان",
        _ => n % 100 is >= 3 and <= 10 ? $"{Ui.D(n)} آيات" : $"{Ui.D(n)} آية",
    };

    public static string Narrations(int n) => n switch
    {
        1 => "رواية واحدة", 2 => "روايتان", >= 3 and <= 10 => $"{Ui.D(n)} روايات", _ => $"{Ui.D(n)} رواية",
    };

    private readonly IReadOnlyList<AsbabSurahItem> _all;
    [ObservableProperty] private IReadOnlyList<AsbabSurahItem> _surahs = [];
    [ObservableProperty] private string _filter = "all";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Facts), nameof(Count), nameof(IsEmpty))]
    private AsbabSurahItem? _selected;
    [ObservableProperty] private IReadOnlyList<AsbabGroup> _groups = [];

    public string MeccanCount { get; }
    public string MedinanCount { get; }
    public string NarrationCount => Ui.D(Asbab.Default.All.Count);
    public string HeroSub => $"أسباب نزول من صحيحَي البخاري ومسلم في {Ui.D(Asbab.Default.SurahCount)} سورة";

    public string Title => Selected?.Name ?? "";
    public string Facts => Selected is { } s
        ? $"{s.TypeText} • {AyatCount(s.Surah.Verses.Count)} • ترتيبها في المصحف {Ui.D(s.Surah.Number)}" : "";
    public string Count => Selected is { } s ? (s.HasAsbab ? $"{Narrations(s.Asbab.Count)} في سبب النزول من الصحيحين"
        : "لا رواية فيها في الصحيحين ضمن ما جُمع هنا") : "";
    public bool IsEmpty => Selected is { HasAsbab: false };

    public bool IsAll { get => Filter == "all"; set { if (value) Filter = "all"; } }
    public bool IsMeccan { get => Filter == "meccan"; set { if (value) Filter = "meccan"; } }
    public bool IsMedinan { get => Filter == "medinan"; set { if (value) Filter = "medinan"; } }
    public bool IsWithAsbab { get => Filter == "asbab"; set { if (value) Filter = "asbab"; } }

    public AsbabViewModel()
    {
        var surahs = QuranRepository.Default.Surahs;
        _all = surahs.Select(s => new AsbabSurahItem(s, Asbab.Default.InSurah(s.Number))).ToList();
        var meccan = surahs.Count(s => s.Meccan);
        MeccanCount = Ui.D(meccan);
        MedinanCount = Ui.D(surahs.Count - meccan);
        Surahs = _all;
        Selected = _all.FirstOrDefault(s => s.HasAsbab);
    }

    partial void OnFilterChanged(string value)
    {
        var keep = Selected;
        Surahs = _all.Where(s => value switch
        {
            "meccan" => s.IsMeccan,
            "medinan" => !s.IsMeccan,
            "asbab" => s.HasAsbab,
            _ => true,
        }).ToList();
        OnPropertyChanged(nameof(IsAll));
        OnPropertyChanged(nameof(IsMeccan));
        OnPropertyChanged(nameof(IsMedinan));
        OnPropertyChanged(nameof(IsWithAsbab));
        Selected = keep is not null && Surahs.Contains(keep) ? keep : Surahs.FirstOrDefault();
    }

    partial void OnSelectedChanged(AsbabSurahItem? value)
    {
        // Narrations of the same verses share one ayah block.
        Groups = value is null ? [] : value.Asbab.GroupBy(a => (a.From, a.To)).Select(g => new AsbabGroup(
            g.First().AyahLabel, Links.Ayat(value.Surah.Number, g.Key.From, g.Key.To, "", maxShown: 4),
            g.Select(a => new SababView(a)).ToList())).ToList();
    }

    [RelayCommand] private static void OpenInQuran(AyatBlock? a) => Links.OpenInQuran(a);
    [RelayCommand] private static void ReciteAyat(AyatBlock? a) => Links.Recite(a);
}

// ============================================================ غزوات النبي ﷺ

public sealed record GhazwaItem(Ghazwa G)
{
    public string YearText => $"{Ui.D(G.Year)} هـ";
    public string Name => G.Name;
    public string Date => G.Date;
    public bool IsTreaty => !G.IsBattle;
}

public sealed record FactItem(string Label, string Value);

/// <summary>The battles of the Prophet ﷺ: story, Qur'an passages, hadith of the two Sahihs, lessons, references and the recorded narration.</summary>
public sealed partial class GhazawatViewModel : ObservableObject
{
    private const string AudioPrefix = "ghazwa-";
    public GhazawatBook Book => GhazawatBook.Default;
    public IReadOnlyList<GhazwaItem> Items { get; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Title), nameof(Subtitle), nameof(Summary), nameof(Facts), nameof(Sections), nameof(Ayat),
        nameof(HasAyat), nameof(Lessons), nameof(Refs), nameof(HasRefs), nameof(IsTreaty), nameof(IsPlaying), nameof(IsMine),
        nameof(ListenLabel), nameof(ListenGlyph))]
    private GhazwaItem? _selected;

    public string Title => Selected?.Name ?? "";
    public string Subtitle => Selected is { } s ? $"{s.G.Date} • {s.G.Place}" : "";
    public string Summary => Selected?.G.Summary ?? "";
    public bool IsTreaty => Selected?.IsTreaty == true;
    public IReadOnlyList<FactItem> Facts => Selected?.G is not { } g ? [] : new[]
    {
        new FactItem("المسلمون", g.Muslims ?? ""),
        new FactItem(g.IsBattle ? "في المقابل" : "الطرف الآخر", g.Enemy ?? ""),
        new FactItem("النتيجة", g.Result ?? ""),
    }.Where(f => f.Value.Length > 0).ToList();
    public IReadOnlyList<SectionView> Sections => Selected?.G.Sections
        .Select(s => new SectionView(s.Heading, s.Text.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(t => new Paragraph(t)).ToList())).ToList() ?? [];
    public IReadOnlyList<AyatBlock> Ayat => Selected?.G.Ayat
        .Where(a => a.Surah is >= 1 and <= 114)
        .Select(a => Links.Ayat(a.Surah, a.From, a.To ?? a.From, a.Note ?? "")).ToList() ?? [];
    public bool HasAyat => Ayat.Count > 0;
    [ObservableProperty] private IReadOnlyList<HadithLink> _hadith = [];
    public IReadOnlyList<string> Lessons => Selected?.G.Lessons ?? [];
    public IReadOnlyList<LinkItem> Refs => Selected?.G.Refs?.Select(r => new LinkItem(r.Title, r.Url)).ToList() ?? [];
    public bool HasRefs => Refs.Count > 0;
    public IReadOnlyList<LinkItem> Sources => Book.Sources?.Select(r => new LinkItem(r.Title, r.Url)).ToList() ?? [];

    // ---------------- audio (recorded narration, male voice) ----------------
    private static Services.NarrationService N => App.Instance.Narration;
    public bool IsMine => Selected is { } s && N.IsSpeaking && N.CurrentId == AudioPrefix + s.G.Id;
    public bool IsPlaying => IsMine && !N.IsPaused;
    public string ListenLabel => !IsMine ? "استمع" : IsPlaying ? "إيقاف مؤقت" : "متابعة";
    public string ListenGlyph => IsPlaying ? "" : "";
    [ObservableProperty] private string _audioStatus = "";

    public GhazawatViewModel()
    {
        Items = Book.Items.Select(g => new GhazwaItem(g)).ToList();
        N.StateChanged += () => App.Instance.Dispatcher.BeginInvoke(() =>
        {
            OnPropertyChanged(nameof(IsMine));
            OnPropertyChanged(nameof(IsPlaying));
            OnPropertyChanged(nameof(ListenLabel));
            OnPropertyChanged(nameof(ListenGlyph));
        });
        N.PartFailed += (id, _) => App.Instance.Dispatcher.BeginInvoke(() =>
        {
            if (Selected is { } s && id == AudioPrefix + s.G.Id)
                AudioStatus = "التسجيل الصوتي لهذه الغزوة غير متاح الآن (لم يُنشر بعد أو لا يوجد اتصال بالإنترنت).";
        });
        Selected = Items.FirstOrDefault();
    }

    partial void OnSelectedChanged(GhazwaItem? value)
    {
        AudioStatus = "";
        Hadith = value is null ? [] : value.G.Hadith.Select(r =>
            new HadithLink($"{r.Title} • {r.CollectionName} {Ui.D(r.Number)}", r.Find)).ToList();
        foreach (var h in Hadith) { h.IsOpen = true; _ = h.LoadAsync(); }
    }

    [RelayCommand]
    private void Listen()
    {
        if (Selected is not { } s) return;
        if (IsMine) { N.TogglePause(); return; }
        App.Instance.Recitation.Stop();
        AudioStatus = "";
        N.PlayRecording(AudioPrefix + s.G.Id, s.G.Name, "بصوت مازن", "غزوات النبي ﷺ – سبيل", s.G.AudioUrl, "ghazawat");
    }

    [RelayCommand] private void StopAudio() { if (IsMine) N.Stop(); }
    [RelayCommand] private void SeekBack() { if (IsMine) N.Seek(-15); }
    [RelayCommand] private void SeekForward() { if (IsMine) N.Seek(15); }
    [RelayCommand] private void OpenMap() { if (Selected is { } s) Links.Open(AtlasBook.MapUrl(s.G.Lat, s.G.Lng)); }
    [RelayCommand] private static void OpenUrl(string? url) => Links.Open(url);
    [RelayCommand] private static void OpenInQuran(AyatBlock? a) => Links.OpenInQuran(a);
    [RelayCommand] private static void ReciteAyat(AyatBlock? a) => Links.Recite(a);
}

// ============================================================ النسب الشريف

public sealed partial class AncestorNode(int index, Ancestor a, IReadOnlyList<CompanionNasab> meeting) : ObservableObject
{
    public int Index { get; } = index;
    public string Name => a.Name;
    public string? Note => a.Note;
    public bool HasNote => a.Note is not null;
    public bool IsProphet => Index == 0;
    public bool IsFirst => Index == 0;
    public string BadgeText => Index == 0 ? "ﷺ" : Ui.D(Index);
    public string Subtitle => Index switch { 0 => "رسول الله", 1 => "أبوه ﷺ", 11 => "قريش", _ => "" };
    public bool HasSubtitle => Subtitle.Length > 0;
    /// <summary>The lineage of his mother meets his father's at كلاب.</summary>
    public bool IsMotherMeet => Index == 6;
    public string MeetingCount => Ui.D(meeting.Count);
    public bool HasMeeting => meeting.Count > 0;
    public string MeetingText => $"يلتقي عنده: {string.Join("، ", meeting.Select(c => c.Name))}";
    public bool CanOpen => HasNote || HasMeeting;

    [ObservableProperty] private bool _isOpen;
    /// <summary>The selected companion's lineage meets here.</summary>
    [ObservableProperty] private bool _isHit;
    /// <summary>On the path from the Prophet ﷺ to the selected companion's meeting point.</summary>
    [ObservableProperty] private bool _isLit;
    [ObservableProperty] private string _branch = "";
    public bool ShowDetails => IsOpen || IsHit;
    partial void OnIsOpenChanged(bool value) => OnPropertyChanged(nameof(ShowDetails));
    partial void OnIsHitChanged(bool value) => OnPropertyChanged(nameof(ShowDetails));

    [RelayCommand] private void Toggle() { if (CanOpen) IsOpen = !IsOpen; }
}

public sealed partial class CompanionNasabItem(CompanionNasab c, string meetText) : ObservableObject
{
    public CompanionNasab C { get; } = c;
    public string Name => C.Name;
    public string Clan => C.Clan;
    public string Lineage => C.Lineage;
    public string MeetText { get; } = meetText;
    public string? Remark => C.Remark;
    public bool HasRemark => C.Remark is not null;
    public LinkItem Source => LinkItem.From(C.Source);
    [ObservableProperty] private bool _isSelected;
}

/// <summary>The Prophet's ﷺ lineage up to عدنان with sourced notes, and where the lineage of each of the ten meets it.</summary>
public sealed partial class NasabViewModel : ObservableObject
{
    public NasabBook Book => NasabBook.Default;
    public IReadOnlyList<AncestorNode> Chain { get; }
    public IReadOnlyList<CompanionNasabItem> Companions { get; }
    public string HeroSub => $"من محمد ﷺ إلى عدنان • {Ui.D(Book.Chain.Count - 1)} أبًا";
    public LinkItem Zad => LinkItem.From(Book.Zad);
    public LinkItem MotherSource => LinkItem.From(Book.MotherSource);
    public IReadOnlyList<LinkItem> Sources => Book.Sources.Select(LinkItem.From).ToList();
    public const string FootnoteText = "سلسلة النسب كما ساقها البخاري في ترجمة «باب مبعث النبي ﷺ»، والنبذ عن الأجداد مختصرة من شرح ابن حجر لهذا الباب في فتح الباري، "
        + "وما فيها بصيغة «قيل» فهو مما نقله من أقوال أهل اللغة والنسب. وملتقى أنساب الصحابة منقول من فتح الباري وسير أعلام النبلاء وسيرة ابن هشام.";
    public string Footnote => FootnoteText;
    [ObservableProperty] private CompanionNasabItem? _selected;
    [ObservableProperty] private string _selectedText = "";

    public NasabViewModel()
    {
        var chain = Book.Chain;
        Chain = chain.Select((a, i) => new AncestorNode(i, a, Book.Companions.Where(c => c.Meet == i).ToList())).ToList();
        Companions = Book.Companions.Select(c => new CompanionNasabItem(c,
            c.Meet + 1 < chain.Count ? $"{c.Chain[^1]} بن {chain[c.Meet + 1].Name}" : c.Chain[^1])).ToList();
        foreach (var c in Companions)
            c.PropertyChanged += (_, e) =>
            {
                if (e.PropertyName != nameof(CompanionNasabItem.IsSelected)) return;
                if (c.IsSelected) Selected = c;
                else if (Selected == c) Selected = null;
            };
    }

    partial void OnSelectedChanged(CompanionNasabItem? oldValue, CompanionNasabItem? newValue)
    {
        if (oldValue is not null && oldValue != newValue) oldValue.IsSelected = false;
        var meet = newValue?.C.Meet ?? -1;
        foreach (var n in Chain)
        {
            n.IsHit = n.Index == meet;
            n.IsLit = meet >= 0 && n.Index <= meet;
            n.Branch = n.IsHit && newValue is not null ? $"{newValue.Name} رضي الله عنه: {newValue.Lineage}" : "";
        }
        SelectedText = newValue is null ? "" : $"يلتقي نسب {newValue.Name} بنسب النبي ﷺ عند {newValue.MeetText}";
        MeetRequested?.Invoke(meet);
    }

    /// <summary>The view scrolls the tree to this node.</summary>
    public event Action<int>? MeetRequested;

    [RelayCommand] private static void OpenUrl(string? url) => Links.Open(url);
}

// ============================================================ كيف أسلم الصحابة

public sealed record CompanionIslamView(CompanionIslam C, int N)
{
    public string NumberText => Ui.D(N);
    public string Name => $"{C.Name} رضي الله عنه";
    public string By => C.By;
    public string Story => C.Story;
    public bool HasAge => C.Age is not null;
    public string Age => $"عمره حين أسلم: {C.Age}";
    public bool AgeDisputed => C.AgeDisputed;
    public bool HasHadith => C.Hadith is not null;
    public string HadithText => C.Hadith?.Text ?? "";
    public string HadithRef => C.Hadith is { } h ? $"صحيح البخاري {Ui.D(h.Number)}" : "";
    public IReadOnlyList<LinkItem> Sources { get; } = C.Sources.Select(LinkItem.From).ToList();
}

/// <summary>How and when each of the ten promised Paradise embraced Islam.</summary>
public sealed partial class CompanionsIslamViewModel : ObservableObject
{
    public CompanionsIslamBook Book => CompanionsIslamBook.Default;
    public IReadOnlyList<CompanionIslamView> Items { get; }
    public string HeroSub => $"العشرة المبشرون بالجنة • {Ui.D(Book.List.Count)} سِيَر";
    public string StatAbuBakr => $"{Ui.D(Book.List.Count(c => c.By.Contains("أبي بكر")))} بدعوة أبي بكر";
    public string StatHadith => $"{Ui.D(Book.List.Count(c => c.Hadith is not null))} بحديث من البخاري";

    public CompanionsIslamViewModel() => Items = Book.List.Select((c, i) => new CompanionIslamView(c, i + 1)).ToList();

    [RelayCommand] private static void OpenUrl(string? url) => Links.Open(url);
}

// ============================================================ التقويم الميلادي

public sealed record CalendarCell(DateOnly? Date, string DayText, string HijriText, bool IsToday, bool IsSpecial, bool IsWhite,
    bool IsFriday, IReadOnlyList<string> Events)
{
    public bool IsBlank => Date is null;
    public string Tooltip => Date is { } d
        ? $"{Ui.Date(d)}\n{Core.HijriDate.From(d, App.Instance.Settings.Current.HijriAdjustmentDays).ToDisplay(true)}"
          + (Events.Count > 0 ? "\n" + string.Join("\n", Events.Select(e => "• " + e)) : "")
        : "";
}

public sealed record CalendarEvent(string DayText, string Name, string Subtitle);

/// <summary>The Gregorian month (Saturday first) with the Hijri day under each date, the occasions and the white days.</summary>
public sealed partial class CalendarViewModel : ObservableObject
{
    public IReadOnlyList<string> Weekdays { get; } = ["سبت", "أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة"];
    private DateOnly _month;
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _hijriSpan = "";
    [ObservableProperty] private IReadOnlyList<CalendarCell> _cells = [];
    [ObservableProperty] private IReadOnlyList<CalendarEvent> _events = [];
    [ObservableProperty] private bool _isCurrentMonth = true;
    [ObservableProperty] private CalendarCell? _selectedDay;
    [ObservableProperty] private string _selectedTitle = "";
    [ObservableProperty] private string _selectedHijri = "";
    [ObservableProperty] private string _selectedEvents = "";

    public CalendarViewModel()
    {
        var t = App.Instance.Today;
        _month = new DateOnly(t.Year, t.Month, 1);
        App.Instance.Settings.Changed += _ => App.Instance.Dispatcher.BeginInvoke(Reload);
        Reload();
    }

    [RelayCommand] private void PrevMonth() { _month = _month.AddMonths(-1); Reload(); }
    [RelayCommand] private void NextMonth() { _month = _month.AddMonths(1); Reload(); }
    [RelayCommand] private void ThisMonth() { var t = App.Instance.Today; _month = new DateOnly(t.Year, t.Month, 1); Reload(); }
    [RelayCommand] private void SelectDay(CalendarCell? c) { if (c is { IsBlank: false }) SelectedDay = c; }

    public void Reload()
    {
        var adj = App.Instance.Settings.Current.HijriAdjustmentDays;
        var today = App.Instance.Today;
        var days = DateTime.DaysInMonth(_month.Year, _month.Month);
        var last = new DateOnly(_month.Year, _month.Month, days);
        Title = _month.ToDateTime(TimeOnly.MinValue).ToString("MMMM yyyy", Localization.Loc.I.Culture);
        Title = Ui.D(Title);
        var h1 = Core.HijriDate.From(_month, adj);
        var h2 = Core.HijriDate.From(last, adj);
        HijriSpan = h1.Month == h2.Month
            ? $"{h1.MonthName(true)} {Ui.D(h1.Year)} هـ"
            : $"{h1.MonthName(true)} – {h2.MonthName(true)} {Ui.D(h2.Year)} هـ";
        IsCurrentMonth = _month.Year == today.Year && _month.Month == today.Month;

        var lead = ((int)_month.DayOfWeek + 1) % 7; // Saturday first
        var cells = new List<CalendarCell>();
        for (var i = 0; i < lead; i++) cells.Add(new CalendarCell(null, "", "", false, false, false, false, []));
        var events = new List<CalendarEvent>();
        for (var d = _month; d <= last; d = d.AddDays(1))
        {
            var h = Core.HijriDate.From(d, adj);
            var ev = CalendarEvents.On(d, adj);
            var special = ev.Any(e => e != "الأيام البيض" && !e.StartsWith("بداية "));
            cells.Add(new CalendarCell(d, Ui.D(d.Day), Ui.D(h.Day), d == today, special, CalendarEvents.IsWhiteDay(h),
                d.DayOfWeek == DayOfWeek.Friday, ev));
            events.AddRange(ev.Select(e => new CalendarEvent(Ui.D(d.Day), e, $"{Ui.Date(d)} • {Ui.D(h.ToDisplay(true))}")));
        }
        while (cells.Count % 7 != 0) cells.Add(new CalendarCell(null, "", "", false, false, false, false, []));
        Cells = cells;
        Events = events;
        SelectedDay = cells.FirstOrDefault(c => c.IsToday) ?? cells.First(c => !c.IsBlank);
    }

    partial void OnSelectedDayChanged(CalendarCell? value)
    {
        if (value?.Date is not { } d) return;
        SelectedTitle = Ui.Date(d);
        SelectedHijri = Ui.D(Core.HijriDate.From(d, App.Instance.Settings.Current.HijriAdjustmentDays).ToDisplay(true));
        SelectedEvents = value.Events.Count == 0 ? "لا مناسبة في هذا اليوم" : string.Join("\n", value.Events.Select(e => "• " + e));
    }
}

// ============================================================ أطلس قصص الأنبياء

public sealed record ProphetLink(string Id, string Label);

public sealed record AtlasItem(AtlasPlace P, IReadOnlyList<ProphetLink> Prophets)
{
    public string Name => P.Name;
    public string Note => P.Note;
    public string Source => $"المصدر: سورة {P.Source}";
    public string Certainty => P.CertaintyLabel;
    public string CertaintyColor => P.Certainty switch { "text" => "#12A372", "most" => "#C9A227", _ => "#8A94A6" };
    public string CertaintySoft => "#29" + CertaintyColor[1..];
    public string ProphetNames => string.Join("، ", Prophets.Select(p => p.Label));
    public string Coordinates => FormattableString.Invariant($"{P.Lat:0.###}، {P.Lng:0.###}");
}

/// <summary>
/// Places of the prophets' stories (only those named in the Qur'an or the Sunnah, or identified by most commentators),
/// with the level of certainty. Shown as a list; each place opens in OpenStreetMap.
/// </summary>
public sealed partial class AtlasViewModel : ObservableObject
{
    private readonly IReadOnlyList<AtlasItem> _all;
    public IReadOnlyList<ProphetLink> Filters { get; }
    [ObservableProperty] private string _filter = "";
    [ObservableProperty] private IReadOnlyList<AtlasItem> _items = [];

    public AtlasViewModel()
    {
        var names = QuranRepository.Default.Prophets.ToDictionary(p => p.Id, p => p.NameAr);
        _all = AtlasBook.Default.Places.Select(p => new AtlasItem(p,
            p.Prophets.Where(names.ContainsKey).Select(id => new ProphetLink(id, names[id])).ToList())).ToList();
        var used = _all.SelectMany(a => a.P.Prophets).ToHashSet();
        Filters = new[] { new ProphetLink("", "كل الأنبياء") }
            .Concat(QuranRepository.Default.Prophets.Where(p => used.Contains(p.Id)).Select(p => new ProphetLink(p.Id, p.NameAr))).ToList();
        Items = _all;
    }

    partial void OnFilterChanged(string value) =>
        Items = string.IsNullOrEmpty(value) ? _all : _all.Where(a => a.P.Prophets.Contains(value)).ToList();

    [RelayCommand] private static void OpenMap(AtlasItem? a) { if (a is not null) Links.Open(a.P.MapUrl); }

    [RelayCommand]
    private static void OpenProphet(string? id)
    {
        if (id is null || App.Instance.MainVm is not { } main) return;
        main.Page = Page.Prophets;
        if (main.Prophets.Prophets.FirstOrDefault(p => p.Prophet.Id == id) is { } item) main.Prophets.Selected = item;
    }
}
