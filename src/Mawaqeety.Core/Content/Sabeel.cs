using System.Text.RegularExpressions;

namespace Mawaqeety.Core.Content;

/// <summary>One ayah in an answer, with its tafsir.</summary>
public sealed record SabeelAyah(Surah Surah, int Ayah, string Tafsir)
{
    public string Text => Surah.Verses[Ayah - 1];
}

/// <summary>
/// What «سبيل» found. <see cref="Title"/> says what was understood (e.g. «سورة البقرة — الآية ٢٥٥»);
/// <see cref="Ruling"/> marks a fiqh/fatwa question (refer to scholars); <see cref="More"/> means more ayat matched than shown.
/// </summary>
public sealed record SabeelAnswer(string Title, IReadOnlyList<SabeelAyah> Ayat, IReadOnlyList<Hadith> Hadith, bool Ruling = false, bool More = false)
{
    /// <summary>Entries «من محتوى التطبيق» (fiqh, battles, companions…), best first.</summary>
    public LibraryResult Library { get; init; } = LibraryResult.Empty;

    /// <summary>Found by keywords (not a named ayah or a surah/ayah number).</summary>
    public bool ByKeywords { get; init; }

    public bool IsEmpty => Ayat.Count == 0 && Hadith.Count == 0 && Library.Entries.Count == 0;

    /// <summary>Show the app's content before the ayat: a ruling question, or an entry whose title has every word asked.</summary>
    public bool LibraryFirst => Library.Entries.Count > 0 && (Ruling || Library.Strong);

    internal SabeelAnswer WithRuling(bool r) => r ? this with { Ruling = true } : this;
}

/// <summary>
/// «سبيل»: an offline search that answers «تفسير آية…» or «حديث عن…» questions from the bundled Quran,
/// التفسير الميسر and the two Sahih collections. No AI: it only finds and quotes sources.
/// A port of the mobile app's lib/data/sabeel.dart (same rules, same results).
/// </summary>
public sealed class Sabeel
{
    private static readonly Lazy<Sabeel> _default = new(() => new Sabeel(QuranRepository.Default, Content.Tafsir.Default,
        HadithCollection.Ids.Select(HadithCollection.Load).ToList(), SabeelLibrary.Default));
    public static Sabeel Default => _default.Value;

    private readonly QuranRepository _repo;
    public Tafsir Tafsir { get; }
    private readonly IReadOnlyList<HadithCollection> _hadith;
    private readonly Dictionary<string, int> _surahNames = [];
    private readonly string[][] _verseKeys;
    private readonly SabeelLibrary? _library;

    public Sabeel(QuranRepository repo, Tafsir tafsir, IReadOnlyList<HadithCollection> hadith, SabeelLibrary? library = null)
    {
        _repo = repo;
        _library = library;
        Tafsir = tafsir;
        _hadith = hadith;
        foreach (var s in repo.Surahs)
        {
            _surahNames[QuranRepository.Normalize(s.Name)] = s.Number;
            _surahNames[Stem(QuranRepository.Normalize(s.Name))] = s.Number;
        }
        _verseKeys = repo.Surahs.Select(s => s.Verses.Select(QuranRepository.SearchKey).ToArray()).ToArray();
    }

    /// <summary>Well-known names of ayat: (names, surah, from, to, words to find hadith about it).</summary>
    public static readonly IReadOnlyList<(string[] Names, int Surah, int From, int To, string HadithWords)> Named =
    [
        (["ايه الكرسي", "اية الكرسي", "الكرسي"], 2, 255, 255, "آية الكرسي"),
        (["خواتيم البقره", "خواتيم سوره البقره", "اخر البقره", "اواخر البقره", "امن الرسول"], 2, 285, 286, "آخر سورة البقرة"),
        (["ايه الدين", "اية الدين", "ايه المداينه"], 2, 282, 282, ""),
        (["ايه النور", "اية النور", "الله نور السماوات"], 24, 35, 35, ""),
        (["ايات الصيام", "ايه الصيام", "اية الصيام", "ايات الصوم"], 2, 183, 187, ""),
        (["ايه الوضوء", "اية الوضوء", "ايه الطهاره"], 5, 6, 6, ""),
        (["ايات المواريث", "ايه المواريث", "ايه الميراث"], 4, 11, 12, ""),
        (["ايه الكلاله", "اية الكلالة"], 4, 176, 176, ""),
        (["ايه الاسراء", "سبحان الذي اسري"], 17, 1, 1, ""),
        (["ايه الحجاب", "اية الحجاب"], 33, 53, 53, "آية الحجاب"),
        (["ايه التيمم", "اية التيمم"], 4, 43, 43, "آية التيمم"),
        (["ايه البر", "ليس البر"], 2, 177, 177, ""),
        (["ايه الشوري", "وامرهم شوري"], 42, 38, 38, ""),
        (["ايه الصلاه علي النبي", "ان الله وملائكته يصلون"], 33, 56, 56, ""),
        (["اكملت لكم دينكم", "ايه اكمال الدين"], 5, 3, 3, "اليوم أكملت لكم دينكم"),
        (["قل هو الله احد", "سوره الاخلاص"], 112, 1, 4, "قل هو الله أحد"),
        (["المعوذتين", "المعوذات"], 113, 1, 5, "المعوذات"),
        (["ام الكتاب", "السبع المثاني", "الفاتحه"], 1, 1, 7, "فاتحة الكتاب"),
    ];

    private static readonly HashSet<string> Filler =
    [
        "تفسير", "فسر", "معني", "شرح", "ما", "ماذا", "مااللي", "هو", "هي", "عن", "في", "من", "الي", "علي", "ان",
        "ايه", "ايات", "الايه", "الايات", "اية", "آية", "قوله", "تعالي", "حديث", "الحديث", "احاديث", "الاحاديث",
        "هل", "كيف", "لماذا", "ليه", "يقول", "قال", "النبي", "الرسول", "رسول", "صلي", "عليه", "وسلم", "ﷺ", "سوره",
        "السوره", "رقم", "اريد", "عايز", "ابغي", "ورد", "جاء", "الذي", "التي", "اللي", "ايش", "وش", "عند", "و",
    ];
    private static readonly string[] RulingWords = ["حكم", "يجوز", "جايز", "جائز", "حلال", "حرام", "فتوي", "مكروه", "واجب", "كفاره", "افتوني"];

    private static readonly Regex Punct = new(@"[؟?،,.:;!«»""()\[\]-]", RegexOptions.Compiled);
    private static readonly Regex Spaces = new(@"\s+", RegexOptions.Compiled);
    private static readonly Regex RefRx = new(@"([0-9]{1,3})\s*[:/]\s*([0-9]{1,3})(?:\s*-\s*([0-9]{1,3}))?", RegexOptions.Compiled);
    private static readonly Regex Number = new("[0-9]+", RegexOptions.Compiled);
    private static readonly Regex AllDigits = new("^[0-9]+$", RegexOptions.Compiled);

    /// <summary>Arabic-Indic digits → Latin digits.</summary>
    public static string LatinDigits(string s) => string.Concat(s.Select(c => c is >= '٠' and <= '٩' ? (char)('0' + (c - '٠')) : c));

    private static string Plain(string s) => Punct.Replace(QuranRepository.Normalize(s), " ");

    /// <summary>Drops common prefixes so «الصبر», «والصبر» and «بالصبر» all find «صبر».</summary>
    internal static string Stem(string w)
    {
        foreach (var p in new[] { "وبال", "وال", "بال", "فال", "كال", "لل", "ال" })
            if (w.StartsWith(p, StringComparison.Ordinal) && w.Length - p.Length >= 3) return w[p.Length..];
        if (w.Length >= 5 && (w[0] == 'و' || w[0] == 'ف')) return w[1..];
        return w;
    }

    private static string D(int n) => QuranRepository.ArabicDigits(n);

    /// <summary>The query's words without question/filler words, ruling words and numbers (normalized, not stemmed).</summary>
    public static List<string> KeywordsOf(string query) => Keywords(Spaces.Replace(Plain(LatinDigits(query)), " ").Trim());

    /// <summary>True when the query asks for a ruling (حكم، يجوز، حلال…).</summary>
    public static bool IsRuling(string query)
    {
        var tokens = Spaces.Replace(Plain(query), " ").Trim().Split(' ');
        return RulingWords.Any(w => tokens.Any(t => t == w || t.StartsWith(w, StringComparison.Ordinal)));
    }

    /// <summary>Answers <paramref name="query"/> from the Quran, the tafsir, the two Sahihs and the app's own content.</summary>
    public SabeelAnswer Ask(string query)
    {
        var a = AskCore(query);
        if (_library is null) return a;
        // A named ayah or a surah: add only entries that name every word (e.g. «سبب نزول سورة …»).
        return a with { Library = _library.Search(query, titleOnly: !a.ByKeywords && !a.IsEmpty) };
    }

    private SabeelAnswer AskCore(string query)
    {
        var raw = LatinDigits(query);
        var q = Spaces.Replace(Plain(raw), " ").Trim();
        var tokens = q.Split(' ');
        var ruling = RulingWords.Any(w => tokens.Any(t => t == w || t.StartsWith(w, StringComparison.Ordinal)));
        if (q.Length == 0) return new SabeelAnswer("", [], []);

        // 1) "2:255" or "2/255"
        var r = RefRx.Match(raw);
        if (r.Success)
        {
            var a = Range(int.Parse(r.Groups[1].Value), int.Parse(r.Groups[2].Value), r.Groups[3].Success ? int.Parse(r.Groups[3].Value) : null);
            if (a is not null) return a.WithRuling(ruling);
        }

        // 2) A well-known name: «آية الكرسي», «خواتيم البقرة»…
        foreach (var n in Named)
            if (n.Names.Any(k => q.Contains(k, StringComparison.Ordinal)))
            {
                var a = Range(n.Surah, n.From, n.To, n.HadithWords);
                if (a is not null) return a.WithRuling(ruling);
            }

        // 3) A surah by name, with an ayah number or range («الكهف 10», «سورة البقرة آية 255 - 257»).
        var words = tokens;
        var nums = Number.Matches(q).Select(m => int.Parse(m.Value)).ToList();
        for (var i = 0; i < words.Length; i++)
        {
            var two = i + 1 < words.Length ? $"{words[i]} {words[i + 1]}" : null;
            var hasSurahWord = i > 0 && (words[i - 1] == "سوره" || words[i - 1] == "لسوره");
            int? number = two is not null && _surahNames.TryGetValue(two, out var n2) ? n2
                : _surahNames.TryGetValue(words[i], out var n1) ? n1
                : _surahNames.TryGetValue(Stem(words[i]), out var n3) ? n3 : null;
            if (number is not { } num) continue;
            if (nums.Count > 0)
            {
                var a = Range(num, nums[0], nums.Count > 1 && nums[1] > nums[0] ? nums[1] : null);
                if (a is not null) return a.WithRuling(ruling);
            }
            var wi = words[i];
            var rest = Keywords(string.Join(' ', words.Where(w => w != wi && (two is null || !two.Contains(w, StringComparison.Ordinal)))));
            if (hasSurahWord || rest.Count == 0)
            {
                var s = _repo[num];
                if (rest.Count == 0)
                {
                    var show = Math.Min(10, s.Verses.Count);
                    return new SabeelAnswer($"سورة {s.Name} — من أولها", Enumerable.Range(1, show).Select(a => Ayah(num, a)).ToList(),
                        FindHadith([$"سوره {QuranRepository.Normalize(s.Name)}"]), ruling, s.Verses.Count > show);
                }
                return KeywordAnswer(rest, num, ruling);
            }
        }

        // 4) Keywords: search the ayat (and their tafsir) and the hadith.
        var kw = Keywords(q);
        if (kw.Count == 0) return new SabeelAnswer("", [], [], ruling) { ByKeywords = true };
        // «حديث …» quotes a hadith: show only ayat that have every word.
        return KeywordAnswer(kw, null, ruling, exact: tokens.Contains("حديث"));
    }

    private static List<string> Keywords(string q) => q.Split(' ')
        .Where(w => w.Length >= 2 && !Filler.Contains(w) && !RulingWords.Any(r => w.StartsWith(r, StringComparison.Ordinal)) && !AllDigits.IsMatch(w))
        .ToList();

    private SabeelAyah Ayah(int s, int a) => new(_repo[s], a, Tafsir.Of(s, a));

    private SabeelAnswer? Range(int s, int from, int? to, string hadithWords = "")
    {
        if (s < 1 || s > 114) return null;
        var surah = _repo[s];
        if (from < 1 || from > surah.Verses.Count) return null;
        var end = Math.Clamp(to ?? from, from, surah.Verses.Count);
        if (end - from > 9) end = from + 9;
        var title = from == end
            ? $"سورة {surah.Name} — الآية {D(from)}"
            : $"سورة {surah.Name} — الآيات {D(from)}–{D(end)}";
        var ayat = Enumerable.Range(from, end - from + 1).Select(a => Ayah(s, a)).ToList();
        return new SabeelAnswer(title, ayat, hadithWords.Length == 0 ? [] : FindHadith([QuranRepository.Normalize(hadithWords)]));
    }

    private SabeelAnswer KeywordAnswer(List<string> kw, int? onlySurah, bool ruling, bool exact = false)
    {
        var stems = kw.Select(Stem).ToList();
        var verseKeys = stems.Select(QuranRepository.SearchKey).ToList();
        var phrase = QuranRepository.SearchKey(string.Join(' ', kw));
        var full = new List<(int Score, int S, int A)>();
        var partial = new List<(int Score, int S, int A)>();
        for (var s = 1; s <= 114; s++)
        {
            if (onlySurah is { } only && s != only) continue;
            var verses = _verseKeys[s - 1];
            for (var a = 1; a <= verses.Length; a++)
            {
                var v = verses[a - 1];
                var t = Tafsir.Normalized(s, a);
                int score = 0, found = 0;
                for (var i = 0; i < stems.Count; i++)
                {
                    // Without its alefs a word can shrink to two letters («ربا» → «رب»): match it in the tafsir only.
                    bool inV = verseKeys[i].Length >= 3 && Has(v, verseKeys[i]), inT = Has(t, stems[i]);
                    if (inV || inT) found++;
                    if (inV) score += 3;
                    if (inT) score += 1;
                }
                if (found == stems.Count)
                {
                    if (kw.Count > 1 && v.Contains(phrase, StringComparison.Ordinal)) score += 10;
                    full.Add((score, s, a));
                }
                else if (!exact && stems.Count > 1 && found == stems.Count - 1)
                {
                    partial.Add((score, s, a));
                }
            }
        }
        static List<(int Score, int S, int A)> Sorted(List<(int Score, int S, int A)> l) =>
            l.OrderByDescending(x => x.Score).ThenBy(x => x.S * 1000 + x.A).ToList();
        var scored = full.Count >= 5 ? Sorted(full) : [.. Sorted(full), .. Sorted(partial)];
        var top = scored.Take(12).Select(e => Ayah(e.S, e.A)).ToList();
        var where = onlySurah is { } o ? $" في سورة {_repo[o].Name}" : "";
        return new SabeelAnswer($"نتائج «{string.Join(' ', kw)}»{where}", top, onlySurah is null ? FindHadith(stems) : [],
            ruling, scored.Count > top.Count) { ByKeywords = onlySurah is null };
    }

    private static readonly Dictionary<string, Regex> Re = [];

    /// <summary>
    /// A word that starts with <paramref name="w"/> (after و/ف/ب/ل/ك and «ال»): «صبر» finds «والصبر» and «صبروا»
    /// but «ربا» does not find «أقربائكم». Two-letter words (بر، حج) must be the whole word.
    /// </summary>
    internal static bool Has(string text, string w)
    {
        Regex? re;
        lock (Re)
            if (!Re.TryGetValue(w, out re))
                Re[w] = re = new Regex($"(^|[^ء-ي])(و|ف)?(ب|ل|ك)?(ال|ل)?{Regex.Escape(w)}{(w.Length <= 2 ? "([^ء-ي]|$)" : "")}", RegexOptions.CultureInvariant);
        return re.IsMatch(text);
    }

    private static readonly Regex NonLetter = new("[^ء-ي]", RegexOptions.Compiled);

    private static string Head(Hadith h)
    {
        var p = NonLetter.Replace(HadithCollection.Plain(h.Matn), "");
        return p.Length > 50 ? p[..50] : p;
    }

    /// <summary>Hadith whose text has every word; the Prophet's ﷺ own words first, shortest first.</summary>
    private List<Hadith> FindHadith(IEnumerable<string> words, int max = 8)
    {
        var q = string.Join(' ', words.Select(HadithCollection.Plain));
        var found = _hadith.SelectMany(c => c.Search(q, 60))
            .OrderBy(h => h.HasMatn && h.Matn.Contains('"') ? 0 : 1)
            .ThenBy(h => h.Matn.Length);
        var seen = new HashSet<string>();
        return found.Where(h => seen.Add(Head(h))).Take(max).ToList();
    }
}
