namespace Mawaqeety.Core.Content;

/// <summary>
/// An item «من محتوى التطبيق» that «سبيل» can show and open. <see cref="Target"/> names the page (a source id, or
/// «feature») and <see cref="TargetId"/> the item in it (a battle id, a fiqh number, a page name for features).
/// </summary>
public sealed class LibraryEntry(string id, string section, string title, string target, string targetId,
    string snippet = "", string text = "", string keywords = "", string? source = null, bool feature = false)
{
    public string Id { get; } = id;
    public string Section { get; } = section;
    public string Title { get; } = title;
    public string Snippet { get; } = Short(snippet);
    public string? Source { get; } = string.IsNullOrWhiteSpace(source) ? null : source;
    public bool Feature { get; } = feature;
    public string Target { get; } = target;
    public string TargetId { get; } = targetId;

    internal readonly string[] TitleWords = Words($"{title} {keywords}");
    internal readonly string[] TextWords = Words($"{snippet} {text}");
    internal readonly string TitleKey = QuranRepository.SearchKey(title);

    private static string Short(string s)
    {
        var t = string.Join(' ', s.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (t.Length <= 150) return t;
        var cut = t.LastIndexOf(' ', 150);
        return t[..(cut < 80 ? 150 : cut)] + "…";
    }

    /// <summary>Distinct search keys of the words, without the prefixes و/ف/ب/ال (as the mobile app).</summary>
    private static string[] Words(string s) => System.Text.RegularExpressions.Regex
        .Split(QuranRepository.Normalize(s), "[^ء-يa-z0-9]+")
        .Where(w => w.Length > 0)
        .Select(w => QuranRepository.SearchKey(Sabeel.Stem(w)))
        .Where(w => w.Length > 0)
        .Distinct()
        .ToArray();
}

/// <summary>One registered section: its name, the embedded resources it indexes and how to build its entries.</summary>
public sealed record LibrarySource(string Id, string Section, Func<IEnumerable<LibraryEntry>> Build, params string[] Resources);

public sealed record LibraryResult(IReadOnlyList<LibraryEntry> Entries, bool Strong = false)
{
    public static readonly LibraryResult Empty = new([]);
}

/// <summary>
/// «من محتوى التطبيق»: an index of the app's sections so «سبيل» answers from the app's own content
/// (a port of mobile/lib/data/sabeel_library.dart, same rules).
/// TO ADD A NEW SECTION: add one <see cref="LibrarySource"/> to <see cref="Sources"/> and, in the app,
/// one case in SabeelViewModel.Open for its page. LibraryTests fails if an embedded content resource is not registered.
/// </summary>
public sealed class SabeelLibrary
{
    public const int MaxResults = 30, Shown = 6;
    public IReadOnlyList<LibraryEntry> Entries { get; }
    public SabeelLibrary(IReadOnlyList<LibraryEntry> entries) => Entries = entries;

    // ───────────────────────── The registry: one line per section ─────────────────────────
    public static readonly IReadOnlyList<LibrarySource> Sources =
    [
        new("fiqh", "فقه العبادات", Fiqh, "fiqh.json"),
        new("ghazawat", "غزوات النبي ﷺ", Ghazawat, "ghazawat.json"),
        // The Seerah timeline (mobile assets/data/seerah.json) is not in the desktop app yet; register it here when ported.
        new("companions_islam", "كيف أسلم الصحابة", CompanionsIslam, "companions_islam.json"),
        new("companions", "العشرة المبشرون بالجنة", Companions, "companions.json"),
        new("nasab", "النسب الشريف", Nasab, "nasab.json"),
        new("prophets", "قصص الأنبياء", Prophets, "prophets.json"),
        new("arbaeen", "الأربعون النووية", Arbaeen, "arbaeen.json"),
        new("asbab", "أسباب النزول", AsbabEntries, "asbab.json"),
        new("asma", "أسماء الله الحسنى", Asma),
        new("occasions", "المناسبات والصيام", OccasionEntries),
        new("duas", "أدعية المناسبات", Duas, "duas.json"),
        new("adhkar", "أذكار الصباح والمساء", Adhkar, "adhkar.json"),
        new("atlas", "أطلس قصص الأنبياء", Atlas, "atlas.json"),
        // Hajj guide (feature/hajj: hajj.json), when it is merged and ported:
        // new("hajj", "دليل الحج والعمرة", Hajj, "hajj.json"),
        new("feature", "ميزات التطبيق", Features),
    ];

    /// <summary>Embedded data that is not content to quote: the Quran, tafsir and Sahihs (searched by <see cref="Sabeel"/>) and app data.</summary>
    public static readonly IReadOnlySet<string> NotContent = new HashSet<string>
    {
        "quran.json", "mushaf.json", "mushaf_ayahs.json", "tafsir_muyassar.json.gz", "hadith_bukhari.json.gz", "hadith_muslim.json.gz",
        "cities.json", "reciters.json", "palettes.json", "story_audio.json",
    };

    // After Sources (static fields initialise in order); the index is built once, on the first question.
    private static readonly Lazy<SabeelLibrary> _default = new(() => new SabeelLibrary(Sources.SelectMany(s => s.Build()).ToList()));
    public static SabeelLibrary Default => _default.Value;

    public static IReadOnlySet<string> CoveredResources => Sources.SelectMany(s => s.Resources).ToHashSet();

    private static readonly HashSet<string> Filler = ["كم", "متي", "اين", "كان", "كانت", "يكون", "تكون", "اعرف", "ابحث", "اسال", "عايزه", "نبي", "لي"];

    /// <summary>
    /// Entries for <paramref name="query"/>, best first: a word in the title counts more than in the text; every word must be
    /// found (or all but one for three words or more). <paramref name="titleOnly"/> keeps entries with every word in the title.
    /// </summary>
    public LibraryResult Search(string query, bool titleOnly = false)
    {
        var kw = Sabeel.KeywordsOf(query).Where(w => !Filler.Contains(w))
            .Select(w => QuranRepository.SearchKey(Sabeel.Stem(w))).Where(w => w.Length > 0).Distinct().ToList();
        if (kw.Count == 0) return LibraryResult.Empty;
        var ruling = Sabeel.IsRuling(query);
        var phrase = string.Join(' ', kw);
        var need = kw.Count >= 3 ? kw.Count - 1 : kw.Count;
        var hits = new List<(int Score, int InTitle, int Order, LibraryEntry E)>();
        for (var i = 0; i < Entries.Count; i++)
        {
            var e = Entries[i];
            int score = 0, found = 0, inTitle = 0;
            foreach (var k in kw)
            {
                if (Has(e.TitleWords, k)) { score += e.TitleWords.Contains(k) ? 4 : 3; found++; inTitle++; }
                else if (Has(e.TextWords, k)) { score += 1; found++; }
            }
            if (found < need || (titleOnly && inTitle < kw.Count)) continue;
            if (found < kw.Count) score -= 2;
            if (kw.Count > 1 && e.TitleKey.Contains(phrase, StringComparison.Ordinal)) score += 4;
            if (ruling && e.Target == "fiqh") score += 3;
            hits.Add((score, inTitle, i, e));
        }
        var sorted = hits.OrderByDescending(h => h.Score).ThenBy(h => h.Order).ToList();
        return new LibraryResult(sorted.Take(MaxResults).Select(h => h.E).ToList(), sorted.Count > 0 && sorted[0].InTitle == kw.Count);
    }

    /// <summary>A word that starts with <paramref name="k"/> (words of two letters must be whole).</summary>
    private static bool Has(string[] words, string k) =>
        k.Length <= 2 ? words.Contains(k) : words.Any(w => w.StartsWith(k, StringComparison.Ordinal));

    private static string D(int n) => QuranRepository.ArabicDigits(n);

    // ───────────────────────── Sources ─────────────────────────

    private static IEnumerable<LibraryEntry> Fiqh() => FiqhBook.Default.Items.Select(i => new LibraryEntry(
        $"fiqh:{i.Id}", "فقه العبادات", i.Question, "fiqh", i.Id.ToString(),
        snippet: i.Answers.FirstOrDefault()?.Text ?? "",
        text: $"{i.Topic} {i.Sub} {string.Join(' ', i.Answers.Select(a => a.Text))}",
        keywords: i.Sub,
        source: string.Join(" • ", i.Answers.Select(a => $"{a.Source}: {a.Ref}"))));

    private static IEnumerable<LibraryEntry> Ghazawat() => GhazawatBook.Default.Items.Select(g => new LibraryEntry(
        $"ghazawat:{g.Id}", "غزوات النبي ﷺ", g.Name, "ghazawat", g.Id,
        snippet: $"{g.Date} — {g.Place}. {g.Summary}",
        text: $"{g.Muslims} {g.Enemy} {g.Result} {string.Join(' ', g.Sections.Select(s => $"{s.Heading} {s.Text}"))} {string.Join(' ', g.Lessons)}"));

    private static IEnumerable<LibraryEntry> CompanionsIslam() => CompanionsIslamBook.Default.List.Select(c => new LibraryEntry(
        $"companions_islam:{c.Id}", "كيف أسلم الصحابة", $"إسلام {c.Name}", "companions_islam", c.Id,
        snippet: $"{c.By}. {c.Story}", text: $"{c.Age} {c.Hadith?.Text}", keywords: $"كيف اسلم {c.Name}",
        source: c.Sources.FirstOrDefault()?.Label));

    private static IEnumerable<LibraryEntry> Companions() => CompanionsBook.Default.Companions.Select(c => new LibraryEntry(
        $"companions:{c.Id}", "العشرة المبشرون بالجنة", c.Name, "companions", c.Id,
        snippet: $"{c.Title}. {c.Bio}", text: string.Join(' ', c.Situations.Select(s => $"{s.Title} {s.Text}"))));

    private static IEnumerable<LibraryEntry> Nasab()
    {
        var b = NasabBook.Default;
        yield return new LibraryEntry("nasab:prophet", "النسب الشريف", "نسب النبي ﷺ", "nasab", "",
            snippet: b.Intro, text: $"{b.Agreed} {b.Mother} {string.Join(' ', b.Chain.Select(a => $"{a.Name} {a.Note}"))}",
            keywords: "النسب الشريف نسب الرسول ام النبي امه", source: b.BukhariRef);
        foreach (var n in b.Companions)
            yield return new LibraryEntry($"nasab:{n.Id}", "النسب الشريف", $"نسب {n.Name}", "nasab", n.Id,
                snippet: $"{n.Lineage}. يلتقي مع النبي ﷺ عند {n.Chain[^1]}. {n.Remark}", source: n.Source.Label);
    }

    private static IEnumerable<LibraryEntry> Prophets() => QuranRepository.Default.Prophets.Select(p => new LibraryEntry(
        $"prophets:{p.Id}", "قصص الأنبياء",
        $"قصة {(p.Id == "muhammad" ? "محمد عليه أفضل الصلاة والسلام" : $"{p.NameAr} عليه السلام")}", "prophets", p.Id,
        snippet: p.Summary,
        text: $"{p.Title} {string.Join(' ', p.Sections.Select(s => $"{s.Heading} {s.Body}"))} {string.Join(' ', p.Lessons)}",
        keywords: $"نبي الله {p.NameAr}"));

    private static IEnumerable<LibraryEntry> Arbaeen() => ArbaeenBook.Default.Hadiths.Select(h => new LibraryEntry(
        $"arbaeen:{h.Number}", "الأربعون النووية", $"الحديث {D(h.Number)}: {h.Title}", "arbaeen", h.Number.ToString(),
        snippet: h.Text, text: $"{h.Narrator} {string.Join(' ', h.Benefits ?? [])}", source: h.Takhrij));

    private static IEnumerable<LibraryEntry> AsbabEntries()
    {
        var q = QuranRepository.Default;
        return Asbab.Default.All.Select(s => new LibraryEntry(
            $"asbab:{s.Surah}:{s.From}:{s.Collection}{s.Number}", "أسباب النزول",
            $"سبب نزول سورة {q[s.Surah].Name}، {s.AyahLabel}", "asbab", s.Surah.ToString(),
            snippet: s.Excerpt, keywords: $"سبب نزول {q[s.Surah].Name}", source: s.Ref));
    }

    private static IEnumerable<LibraryEntry> Asma() => AsmaAlHusna.All.Select(n => new LibraryEntry(
        $"asma:{n.Name}", "أسماء الله الحسنى", $"اسم الله «{n.Name}»", "asma", n.Name,
        snippet: n.Meaning, keywords: $"معنى اسم الله {n.Name}"));

    private static IEnumerable<LibraryEntry> OccasionEntries() => Occasions.All.Select(o => new LibraryEntry(
            $"occasions:{o.Id}", "المناسبات والصيام", o.Name, "occasions", o.Id,
            snippet: o.Note, keywords: o.IsFast ? "صيام صوم فضل" : "", source: o.Ref))
        .Append(new LibraryEntry("occasions:monthu", "المناسبات والصيام", "صيام الاثنين والخميس", "occasions", "monthu",
            snippet: Occasions.MonThuNote, keywords: "صوم يوم الاثنين الخميس", source: Occasions.MonThuRef));

    private static IEnumerable<LibraryEntry> Duas()
    {
        var book = DuaBook.Default;
        foreach (var g in book.Groups)
            for (var i = 0; i < g.Sections.Count; i++)
            {
                var s = g.Sections[i];
                var first = s.Items.FirstOrDefault();
                yield return new LibraryEntry($"duas:{g.Id}:{i}", "أدعية المناسبات",
                    s.Title == g.Title ? $"دعاء {g.Title}" : $"{g.Title}: {s.Title}", "duas", g.Id,
                    snippet: first?.Text ?? "", text: string.Join(' ', s.Items.Select(d => $"{d.Text} {d.Virtue}")),
                    keywords: $"دعاء ادعيه ذكر {g.Title}",
                    source: string.IsNullOrEmpty(first?.Source) ? book.Source : first.Source);
            }
    }

    private static IEnumerable<LibraryEntry> Adhkar() => Dhikr.All
        .Select((d, i) => (d, i))
        .Where(x => x.d.Quran.Count == 0 && (x.d.Morning ?? x.d.Evening) is not null)
        .Select(x =>
        {
            var t = (x.d.Morning ?? x.d.Evening)!;
            return new LibraryEntry($"adhkar:{x.i}", "أذكار الصباح والمساء", string.Join(' ', t.Split(' ').Take(7)), "adhkar", x.i.ToString(),
                snippet: t, text: $"{x.d.Evening} {x.d.Virtue}", source: x.d.Source);
        });

    private static IEnumerable<LibraryEntry> Atlas()
    {
        var names = QuranRepository.Default.Prophets.ToDictionary(p => p.Id, p => p.NameAr);
        return AtlasBook.Default.Places.Select(p => new LibraryEntry(
            $"atlas:{p.Name}", "أطلس قصص الأنبياء", p.Name, "atlas", p.Name,
            snippet: p.Note, text: string.Join(' ', p.Prophets.Where(names.ContainsKey).Select(id => names[id])),
            keywords: "مكان اين", source: $"{p.Source} ({p.CertaintyLabel})"));
    }

    /// <summary>The desktop app's pages as entries; <see cref="LibraryEntry.TargetId"/> is the page's name.</summary>
    private static IEnumerable<LibraryEntry> Features()
    {
        LibraryEntry F(string page, string title, string snippet, string keywords) =>
            new($"feature:{page.ToLowerInvariant()}", "ميزات التطبيق", title, "feature", page, snippet: snippet, keywords: keywords, feature: true);
        return
        [
            F("Zakat", "حاسبة الزكاة", "احسب زكاة النقود والذهب والفضة وعروض التجارة، والنصاب (٨٥ جرامًا من الذهب أو ٥٩٥ من الفضة) بسعر الجرام الذي تدخله.",
                "زكاه المال نصاب الزكاه الذهب الفضه حساب الزكاه كم الزكاه"),
            F("Ramadan", "رمضان", "متابعة الصيام والتراويح والتهجد في شهر رمضان.", "رمضان صيام رمضان التراويح التهجد قيام الليل"),
            F("WhiteDays", "الأيام البيض", "صيام ١٣ و١٤ و١٥ من كل شهر هجري ومتابعته.", "الايام البيض صيام ثلاثه ايام من كل شهر"),
            F("Occasions", "المناسبات وصيام السنن", "عرفة وعاشوراء والعيدان والاثنين والخميس بتواريخها.", "مناسبات اسلاميه صيام السنن صيام التطوع"),
            F("Quran", "المصحف", "قراءة القرآن الكريم والبحث فيه. ولتفسير آية اسأل سبيل باسمها أو برقمها.",
                "المصحف قراءه القران سور القران"),
            F("Khatma", "ورد القرآن والختمة", "خطة ختمة ووردك اليومي من القرآن.", "ختمه ختم القران ورد يومي"),
            F("Calendar", "التقويم", "التقويم الميلادي مع التاريخ الهجري والمناسبات والأيام البيض.", "التقويم الهجري التاريخ الهجري الميلادي"),
            F("Monthly", "مواقيت الشهر", "جدول مواقيت الصلاة للشهر كاملًا.", "مواقيت الصلاه جدول الشهر امساكيه"),
            F("Atlas", "أطلس قصص الأنبياء", "أماكن قصص الأنبياء على الخريطة.", "خريطه اطلس اماكن الانبياء"),
            F("Qibla", "اتجاه القبلة", "معرفة اتجاه القبلة من مدينتك.", "القبله اتجاه الكعبه"),
            F("Tasbeeh", "السبحة", "سبحة إلكترونية ووردك اليومي من التسبيح.", "سبحه تسبيح عداد"),
            F("Adhkar", "الأذكار والأدعية", "أذكار الصباح والمساء وأدعية المناسبات من حصن المسلم.", "اذكار الصباح المساء ادعيه حصن المسلم"),
            F("Hadith", "الأحاديث الصحيحة", "تصفّح صحيح البخاري وصحيح مسلم وابحث فيهما.", "صحيح البخاري صحيح مسلم احاديث بحث"),
            F("Stats", "إحصائياتي", "صلواتك وأذكارك ووردك.", "احصائيات متابعه"),
            F("Prophets", "قصص الأنبياء", "قصص الأنبياء من القرآن والسنة الصحيحة.", "قصص الانبياء"),
        ];
    }
}
