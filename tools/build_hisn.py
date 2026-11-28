"""Builds mobile/assets/data/hisn.json: the whole of «حصن المسلم من أذكار الكتاب والسنة» (Sa'id b. Ali b. Wahf
al-Qahtani), its 132 numbered chapters and 267 numbered adhkar, with the book's own takhrij.

Fetched sources (both are transcriptions of the book; the book itself is not in islamweb's library and the
official hisnmuslim.com / wikisource are not reachable from the build machine):
  * TEXT  (fully vowelled, the book's numbering of chapters and adhkar, repetition counts) — the official
    hisnmuslim.com text as packaged in
    https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json
    (category "filename" ar_7esn_AlMoslem_by_Doors_NNN = chapter NNN-1, item "filename" = number of the dhikr).
  * FOOTNOTES (the book's takhrij and virtues, chapter by chapter, in the book's order) —
    https://raw.githubusercontent.com/rn0x/hisn_almuslim_json/main/hisn_almuslim.json
Checked against the app's own data:
  * Qur'an quotations (between ﴿ ﴾ or { }) are located in mobile/assets/data/quran.json by their letters; a
    quotation that is not found stops the build.
  * A dhikr whose takhrij names al-Bukhari or Muslim is looked up in the bundled Sahihs
    (mobile/assets/data/hadith_*.json.gz): the hadith number is kept only when a run of the dhikr's own words is
    found in that collection (with that phrase, re-checked by mobile/test/hisn_test.dart).
Nothing is typed by hand except chapter-title spelling fixes (TITLE_FIX), the topic grouping (TOPICS) and the
reviewed corrections below (TEXT_FIX, TAKHRIJ_FIX, REF_FIX), each with the source it was checked against.
Display: the transcription's (( … )) become « … »; a bracket pair that wraps the whole dhikr, and round brackets
around a run of four words or more (the transcription's marking of the quoted words), are dropped — short notes such
as «(ثلاثاً)» or «(بِاسْمِهِ)» and the book's [ … ] additions stay. In the takhrij, «4/ 2083» becomes «4/2083»
(volume/page as one run, shown with Arabic-Indic numerals by lib/data/hisn.dart).
Grading: the edition graded nothing as weak; the grade shown is the wording of the takhrij itself
(«وصححه الألباني», «وحسن إسناده ابن باز في تحفة الأخيار», a reference to al-Albani's «صحيح …»), or
«في الصحيحين / رواه البخاري / رواه مسلم».

Usage: python3 tools/build_hisn.py <Adhkar-json/adhkar.json> <hisn_almuslim_json/hisn_almuslim.json>
"""
import difflib, gzip, json, re, sys, unicodedata

ADHKAR_URL = "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json"
NOTES_URL = "https://raw.githubusercontent.com/rn0x/hisn_almuslim_json/main/hisn_almuslim.json"
TEXT, NOTES = sys.argv[1], sys.argv[2]
OUT = "mobile/assets/data/hisn.json"

adh = json.load(open(TEXT, encoding="utf-8"))
notes = json.load(open(NOTES, encoding="utf-8"))
quran = json.load(open("mobile/assets/data/quran.json", encoding="utf-8"))
sahih = {c: json.load(gzip.open(f"mobile/assets/data/hadith_{c}.json.gz", "rt", encoding="utf-8"))["h"] for c in ("bukhari", "muslim")}

# Chapter titles: the footnotes file's headings, with spelling slips fixed.
TITLE_FIX = {
    "الذكر عند الدخول المنزل": "الذكر عند دخول المنزل",
    "الدعاء قضاء الدين": "دعاء قضاء الدين",
    "الدعاء حينما يقع مالا يرضاه أو غلب على أمره": "الدعاء حينما يقع ما لا يرضاه أو غُلب على أمره",
    "كفارة المجلس ومايختم به المجالس": "كفارة المجلس",
    "دعاء صياح الديك ونهيق الحمار": "الدعاء عند سماع صياح الديك ونهيق الحمار",
    "التكبيرة إذا أتي الركن الأسود": "التكبير إذا أتى الركن الأسود",
    "التكبيرة عند رمي الجمار مع كل حصاة": "التكبير عند رمي الجمار مع كل حصاة",
    "الدعاء إذا تقلب ليلاً": "الدعاء إذا تقلب ليلًا",
}

# Corrections of the transcription's wording, checked against the cited source: (dhikr number, or (chapter, item
# index) in «فضل الذكر»; the old text, which must occur once; the new text; the source).
TEXT_FIX = [
    (55, "مِنْ عَذَابِ الْقَبْرِ، وَمِنْ عَذَابِ جَهَنَّمَ", "مِنْ عَذَابِ جَهَنَّمَ، وَمِنْ عَذَابِ الْقَبْرِ",
     "the takhrij says «واللفظ لمسلم»; Muslim 588 (app data; www.islamweb.net/ar/library/content/1/995): "
     "«اللهم إني أعوذ بك من عذاب جهنم ومن عذاب القبر ومن فتنة المحيا والممات ومن شر فتنة المسيح الدجال»"),
    (224, "لاَ تَدْخُلُوا الْجَنَّةَ", "لاَ تَدْخُلُونَ الْجَنَّةَ",
     "Muslim 54 (app data; www.islamweb.net/ar/library/content/1/152): «لا تدخلون الجنة حتى تؤمنوا»"),
    (226, "عَبْدِ اللَّهِ بْنِ عُمَرَ", "عَبْدِ اللَّهِ بْنِ عَمْرٍو",
     "the narrator is Abdullah b. Amr: al-Bukhari 12 and Muslim 39 (app data; www.islamweb.net/ar/library/content/1/127)"),
    ((0, 6), "وإن تقرب إلي شبراً", "وإن تقرب إلي بشبر",
     "the takhrij says «واللفظ للبخاري»; al-Bukhari 7405 (app data): «وإن تقرب إلي بشبر تقربت إليه ذراعا»"),
    ((0, 9), "ولا قطيعة رحم", "ولا قطع رحم",
     "Muslim 803 (app data; www.islamweb.net/ar/library/content/1/1408): «في غير إثم ولا قطع رحم»"),
]
# Footnotes whose virtue ran into the takhrij in the transcription: dhikr number → (takhrij, virtue).
TAKHRIJ_FIX = {
    69: ("مسلم 1/418", "من قال ذلك دبر كل صلاة غفرت خطاياه وإن كانت مثل زبد البحر."),
}
# Spelling slips in the takhrij: (dhikr number, old, new).
TAKHRIJ_TYPO = [(165, "سلمم", "مسلم")]
# Sahih references set by hand where the word search picks another hadith: dhikr number → [(col, number, phrase)].
REF_FIX = {
    # «سبحان الله والحمد لله والله أكبر ثلاثاً وثلاثين … تمام المائة» is Muslim 597 (the search found 593, «لا إله
    # إلا الله وحده …» after the salam); www.islamweb.net/ar/library/content/1/1010.
    69: [("muslim", 597, "ثلاثا وثلاثين")],
    # «عشر مرار كان كمن أعتق أربعة أنفس من ولد إسماعيل»: al-Bukhari 6404 (the search found 3293, «مائة مرة»); its
    # Muslim number (2693) is not in the app's Muslim data, so no Muslim number is shown.
    255: [("bukhari", 6404, "من ولد اسماعيل")],
    # After the TEXT_FIX above the wording is Muslim's; al-Bukhari 1377 («من عذاب القبر ومن عذاب النار») stays cited.
    55: [("bukhari", 1377, "ومن فتنه المحيا والممات"), ("muslim", 588, "اعوذ بك من عذاب جهنم ومن عذاب القبر")],
    # Muslim 2042 writes «في ما رزقتهم» in two words, so the word search misses it; 1032 is three words only.
    182: [("muslim", 2042, "واغفر لهم وارحمهم")],
    172: [("bukhari", 1032, "صيبا نافعا")],
    # «من البخل … من الجبن» in this order is al-Bukhari 6365 (6374 has «من الجبن … من البخل»).
    60: [("bukhari", 6365, "اعوذ بك من البخل واعوذ بك من الجبن")],
}

# Topics for the chapter list's filter (chapter numbers as in the book).
TOPICS = [
    ("day", "اليوم والمنزل", "🌅", [1, 2, 3, 4, 5, 10, 11]),
    ("tahara", "الخلاء والوضوء", "💧", [6, 7, 8, 9]),
    ("salah", "المسجد والصلاة", "🕌", list(range(12, 27)) + [32, 33]),
    ("night", "الصباح والمساء والنوم", "🌙", [27, 28, 29, 30, 31]),
    ("distress", "الهم والكرب والشيطان", "💚", list(range(34, 47)) + [106, 125, 126, 128]),
    ("family", "الأولاد والزواج", "👪", [47, 48, 79, 80, 81]),
    ("sick", "المرض والموت والقبور", "🩺", list(range(49, 61)) + [124]),
    ("weather", "الريح والمطر والهلال", "🌧️", list(range(61, 68))),
    ("food", "الطعام والصيام", "🍽️", list(range(68, 77)) + [127]),
    ("travel", "السفر والركوب والسوق", "✈️", list(range(95, 106))),
    ("hajj", "الحج والعمرة", "🕋", list(range(115, 122))),
    ("people", "المجالس والمعاملة", "🤝", [77, 78] + list(range(82, 95)) + list(range(108, 115)) + [122, 123]),
    ("dhikr", "الذكر والاستغفار", "✨", [0, 107, 129, 130, 131, 132]),
]

# ───────────────────────── text helpers ─────────────────────────
DIAC = re.compile("[ً-ٰٟۖ-ۭـ]")


def fix_forms(s):
    """Presentation forms (ﺗﻬ, اﻟﻤﺠ …) → letters; keeps ﷺ."""
    return "".join(unicodedata.normalize("NFKC", c) if ("ﭐ" <= c <= "﷿" or "ﹰ" <= c <= "﻿") and c not in "ﷺﷻ" else c for c in s)


def brackets(t):
    """(( … )) → « … », matching each closing bracket to its opener: «(ثلاثاً)))» is «(ثلاثاً)» then «»»."""
    out, stack, i = [], [], 0
    while i < len(t):
        c = t[i]
        if c == "(":
            double = t[i + 1:i + 2] == "("
            stack.append("«" if double else "(")
            out.append(stack[-1])
            i += 2 if double else 1
            continue
        if c == ")" and stack:
            if stack[-1] == "(":
                stack.pop()
                out.append(")")
                i += 1
                continue
            if t[i + 1:i + 2] == ")":
                stack.pop()
                out.append("»")
                i += 2
                continue
        out.append(c)
        i += 1
    return "".join(out)


def unwrap(t):
    """Drops a bracket pair around the whole text, and round brackets around a run of four words or more."""
    pairs = {"(": ")", "«": "»", "[": "]"}
    while True:
        s = t.strip()
        body = s.rstrip(" .")
        if len(body) < 2 or body[0] not in pairs:
            break
        o, c, depth = body[0], pairs[body[0]], 0
        for j, ch in enumerate(body):
            depth += ch == o
            depth -= ch == c
            if depth == 0:
                break
        if j != len(body) - 1:
            break
        t = body[1:-1].strip() + s[len(body):].strip()

    def long_run(m):
        return m.group(1) if len(m.group(1).split()) >= 4 else m.group(0)
    prev = None
    while prev != t:
        prev = t
        t = re.sub(r"\(([^()]*(?:\([^()]*\)[^()]*)*)\)", long_run, t)
    t = re.sub(r"\]\s*\[", "] [", t)
    t = re.sub(r"»\.(?=\S)", "». ", t)
    t = re.sub(r"([^\s\[(«])\[", r"\1 [", t)
    return re.sub(r"\s+([.،,])", r"\1", t).strip()


def tidy_takhrij(t):
    """«4/ 2083» → «4/2083»; «الترمذي3/144», «418من» → spaced."""
    t = re.sub(r"(\d)\s*/\s*(\d)", r"\1/\2", t)
    t = re.sub(r"([ء-ي])(\d)", r"\1 \2", t)
    t = re.sub(r"(\d)([ء-ي])", r"\1 \2", t)
    return re.sub(r"\s+", " ", t).strip()


def clean(t):
    t = brackets(fix_forms(t))
    t = re.sub("ـ{2,}", "", t)
    t = re.sub(r"[ \t ]+", " ", t)
    t = re.sub(r"\s*\n\s*", "\n", t)
    return t.strip()


def plain(s):
    """Same as HadithCollection.plain (mobile/lib/data/hadith.dart) plus punctuation → spaces."""
    s = DIAC.sub("", fix_forms(s))
    s = re.sub("[أإآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي")
    return re.sub(r"\s+", " ", re.sub(r"[^ء-ي ]", " ", s)).strip()


def skeleton(s):
    """Letters only, without alif/waw/ya/hamza (they differ between the Uthmani and the common spelling)."""
    s = DIAC.sub("", fix_forms(s))
    s = re.sub("[أإآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه")
    s = re.sub("[^ب-ي]|[اويى]", "", s.replace("ء", "").replace("ؤ", "").replace("ئ", ""))
    return re.sub(r"(.)\1+", r"\1", s)  # «الليل» / «ٱلَّيۡلِ»


def sim(a, b):
    return difflib.SequenceMatcher(None, plain(a), plain(b)).ratio()


# ───────────────────────── Qur'an ─────────────────────────
VSK = [[skeleton(v) for v in s["v"]] for s in quran]
SURAH, STARTS = [], []
for vs in VSK:  # the surah's letters, collapsed across verse ends too, and where each verse starts
    joined, st = "", []
    for v in vs:
        st.append(len(joined))
        joined += v[1:] if joined and v and joined[-1] == v[0] else v
    SURAH.append(joined)
    STARTS.append(st)


def find_quran(seg):
    """(surah, from, to, partial) of a quotation, or None: its letters are searched in each surah's letters."""
    k = skeleton(seg)
    if len(k) < 6:
        return None
    for si, joined in enumerate(SURAH):
        i = joined.find(k)
        if i < 0 or (len(k) < 10 and i != STARTS[si][0]):
            continue
        st = STARTS[si]
        a = max(j for j in range(len(st)) if st[j] <= i)
        if a + 1 < len(st) and st[a + 1] == i + 1 and VSK[si][a + 1][:1] == k[:1]:
            a, i = a + 1, i + 1  # the quotation starts with the next verse's first letter (collapsed into this one)
        b = max(j for j in range(len(st)) if st[j] < i + len(k) - 1) if len(k) > 1 else a
        end = st[b + 1] if b + 1 < len(st) else len(joined)
        whole = st[a] in (i, i - 1) and end in (i + len(k) - 1, i + len(k))
        return si + 1, a + 1, b + 1, not whole
    return None


QSEG = re.compile(r"[﴿{]([^﴾}]*)[﴾}]")


def parts_of(text):
    """Splits a text into plain and Qur'an parts: [{"t": …}, {"q": [s, a, b], "src": …, "part": bool}]."""
    out, pos = [], 0
    for m in QSEG.finditer(text):
        seg = m.group(1).strip()
        ref = find_quran(seg)
        if ref is None:
            if skeleton(seg) in ("لم",):  # «الم» as letters, not a quotation
                continue
            raise SystemExit(f"Qur'an quotation not found: {seg[:80]}")
        if m.start() > pos:
            out.append({"t": text[pos:m.start()]})
        s, a, b, part = ref
        q = {"q": [s, a, b], "src": seg}
        if part:
            q["part"] = True
        out.append(q)
        pos = m.end()
    if not out:
        return None
    if pos < len(text):
        out.append({"t": text[pos:]})
    return [p for p in out if "q" in p or p["t"].strip()]


# ───────────────────────── Sahihs ─────────────────────────
# Muslim numbers are Abdul-Baqi's: a repeated hadith keeps its first number, so the sequence is not monotonic
# (tools/build_hadith.py, tools/muslim_numbers.json).
SPLAIN = {c: [(h[1], plain(h[2])) for h in rows] for c, rows in sahih.items()}
NAMES = {"bukhari": "البخاري", "muslim": "مسلم"}


def cites(takhrij, col):
    t = takhrij.replace("البخاري في الأدب المفرد", "").replace("الأدب المفرد للبخاري", "").replace("صحيح مسلم", "")
    t = re.sub(r"(أخرجه|رواه)\s+البخاري\s+في\s+(الأدب|التاريخ)", "", t)
    return ("البخاري" in t) if col == "bukhari" else bool(re.search(r"(^|[\s(،,.و])مسلم\s*(\d|مع|بلفظ|برقم|وغيره|[،,.]|$|و)", t))


def find_hadith(text, col, stated=None):
    """(number, phrase): the hadith of [col] holding the most 5-word runs of the dhikr's quoted words (Qur'an
    quotations left out). Kept only when it holds at least 35% of the runs — a weaker match is usually another
    hadith sharing a common phrase, so the number is left out — or when it is the number the takhrij states."""
    text = QSEG.sub(" ", text)
    quoted = re.findall(r"«([^«»]*)»", text)
    words = plain(" ".join(quoted) if quoted and len(plain(" ".join(quoted)).split()) >= 5 else text).split()
    words = [w for w in words if w not in ("صلي", "الله", "عليه", "وسلم")] if len(words) > 40 else words
    n = 5 if len(words) >= 5 else len(words)
    if n < 3:
        return None
    wins = list(dict.fromkeys(" ".join(words[i:i + n]) for i in range(len(words) - n + 1)))
    score = {}
    for num, p in SPLAIN[col]:
        hits = [w for w in wins if w in p]
        if hits and (num not in score or len(hits) > len(score[num])):
            score[num] = hits
    if not score:
        return None
    best = max(score.items(), key=lambda kv: (len(kv[1]), -kv[0]))
    if stated in score:
        best = (stated, score[stated])
    elif len(best[1]) < 0.35 * len(wins):
        return None
    # The phrase kept for the test: the rarest of the matched runs (fewest hadiths contain it).
    phrase = min(best[1], key=lambda w: (sum(1 for _, p in SPLAIN[col] if w in p), -len(w)))
    return best[0], phrase


def stated_number(takhrij, col):
    """«البخاري 11/116 برقم 6316»: the hadith number the takhrij itself gives, if any."""
    m = re.search(("البخاري" if col == "bukhari" else r"مسلم") + r"[^—]{0,30}?برقم\s*(\d+)", takhrij.replace("البخاري في الأدب المفرد", ""))
    return int(m.group(1)) if m else None


# ───────────────────────── footnotes ─────────────────────────
SRC = re.compile(r"البخاري|مسلم|أبو داود|أبي داود|الترمذي|النسائي|ابن ماجه|أحمد|الحاكم|ابن السني|الطبراني|ابن حبان|البيهقي|"
                 r"ابن خزيمة|مالك|الدارمي|عبد الرزاق|ابن أبي شيبة|سورة|صحيح الجامع|الألباني|ابن باز|الهيثمي|البزار|"
                 r"أبو يعلى|ابن حجر|الفتح|النووي|الأذكار|الأرناؤوط|زاد المعاد|الموطأ|السنن|المستدرك|متفق عليه|إرواء")
LEAD = re.compile(r"\s*[,.،]?\s*(?=(?:أخرجه|رواه|خرجه|البخاري|مسلم|أبو داود|الترمذي|النسائي|ابن ماجه|أحمد|الحاكم|ابن السني|الطبراني|متفق عليه)\b)")


def split_note(f):
    """A footnote → (virtue, takhrij). The virtue is the book's «من قالها …» text before the takhrij."""
    f = clean(f).strip(" .")
    m = LEAD.search(f)
    if m and m.start() > 15 and re.match(r"^(من |إذا |لم |كان |أي )", f):
        return re.sub(r"[\s.،,]+و$", "", f[:m.start()].strip(" .،,")) + ".", f[m.end():].strip()
    return "", f


WHO = (r"(?:(?:العلامة|الشيخ|سماحة الشيخ|الحافظ)\s*)*(?:عبد العزيز بن باز|ابن باز|الألباني|شعيب وعبد القادر الأرناؤوط|"
       r"عبد القادر وشعيب الأرناؤوط|عبد القادر الأرناؤوط|شعيب الأرناؤوط|الأرناؤوط|الذهبي|ابن حجر|الحاكم|الترمذي|النووي|"
       r"ابن حبان والحاكم|ابن حبان|الحافظ)")
GRADE = re.compile(r"(صححه|حسنه|صحح إسناده|حسن إسناده|حسّن إسناده)\s*(" + WHO + r")?(\s*وو(?:ا)?فقه الذهبي)?"
                   r"(\s+(?:في|وفي)\s+[^\d،,.:]+)?")


def grade(takhrij):
    """The grading as the edition words it, or what its takhrij implies."""
    for m in GRADE.finditer(takhrij):
        verb, who, dhahabi, where = m.group(1), m.group(2), m.group(3), m.group(4)
        if not who and dhahabi and "الحاكم" in takhrij[:m.start()]:
            who = "الحاكم"
        if not who:
            continue
        g = f"{verb} {who.strip()}" + (" ووافقه الذهبي" if dhahabi else "")
        if where:
            w = re.sub(r"\s+انظر.*$", "", where.strip().removeprefix("و").strip())
            g += " " + re.sub(r"\s*(برقم|رقم|ص)$", "", w)
        return re.sub(r"\s+", " ", g).strip()
    b, m = cites(takhrij, "bukhari"), cites(takhrij, "muslim")
    if "متفق عليه" in takhrij or (b and m):
        return "في الصحيحين"
    if b or m:
        return "رواه " + ("البخاري" if b else "مسلم") + " في صحيحه"
    m = re.search(r"(?:انظر\s*:?\s*)(صحيح [^\d،,.]+?)\s*(?:\d|برقم)", takhrij)
    if m:
        return f"أورده الألباني في «{m.group(1).strip()}»"
    if re.search(r"سورة", takhrij):
        return "آية من القرآن الكريم"
    return ""


# ───────────────────────── chapters ─────────────────────────
keys = list(notes)
assert keys[0] == "المقدمة" and keys[1] == "فضل الذكر" and len(keys) == 134, keys[:3]
cats = sorted(adh, key=lambda c: (int(c["filename"][-3:]), c["id"]))
assert len(cats) == 132


def title_of(k):
    return TITLE_FIX.get(k, k).strip()


topic_of = {n: t[0] for t in TOPICS for n in t[3]}
fixed = set()
chapters = []
for num in range(0, 133):
    key = keys[num + 1]
    title = title_of(key)
    lines = [clean(t) for t in notes[key]["text"]]
    foot = [f for f in notes[key].get("footnote", []) if f.strip()]
    if num == 0:
        items = [{"text": t, "k": k} for k, t in enumerate(lines)]
    else:
        cat = cats[num - 1]
        if sim(fix_forms(cat["category"]), key) < 0.6:
            print("  title check:", num, fix_forms(cat["category"]), "|", key)
        items = []
        for x in cat["array"]:
            n = int(x["filename"]) if x["filename"].isdigit() else 153  # the one item whose file is the chapter's
            items.append({"n": n, "text": clean(x["text"]), "count": max(1, int(x["count"] or 1))})
    ch = {"n": num, "title": title, "topic": topic_of[num], "url": [NOTES_URL] + ([] if num == 0 else [ADHKAR_URL])}
    if num == 27:  # أذكار الصباح والمساء: kept once, in the «الأذكار» tab (lib/data/adhkar.dart)
        ch["link"] = "adhkar"
        chapters.append(ch)
        continue

    # Footnotes → the footnotes file's lines (only when they pair one to one) → the numbered adhkar.
    tk = [f for f in foot if SRC.search(f) and not f.strip().startswith("*")]
    per_item = [[] for _ in items]
    if len(tk) == len(lines):
        for line, f in zip(lines, tk):
            best = max(range(len(items)), key=lambda i: sim(line, items[i]["text"]))
            if sim(line, items[best]["text"]) > 0.35 or len(items) == 1:
                per_item[best].append(f)
    if all(per_item):
        for it, fs in zip(items, per_item):
            vs, ts = zip(*(split_note(f) for f in fs))
            it["takhrij"] = " — ".join(ts)
            if any(vs):
                it["virtue"] = " ".join(v for v in vs if v)
    else:
        ch["sources"] = [tidy_takhrij(split_note(f)[1]) for f in tk]

    for it in items:
        sel = it["n"] if "n" in it else (num, it.pop("k"))
        for where, old, new, _src in TEXT_FIX:
            if where == sel:  # compared in NFC: the transcription has both orders of shadda and its vowel
                t, old, new = (unicodedata.normalize("NFC", x) for x in (it["text"], old, new))
                assert t.count(old) == 1, (sel, old)
                it["text"] = t.replace(old, new)
                fixed.add(where)
        it["text"] = unwrap(it["text"])
        if sel in TAKHRIJ_FIX:
            it["takhrij"], it["virtue"] = TAKHRIJ_FIX[sel]
        if "takhrij" in it:
            for where, old, new in TAKHRIJ_TYPO:
                if where == sel:
                    assert old in it["takhrij"], (sel, old)
                    it["takhrij"] = it["takhrij"].replace(old, new)
            it["takhrij"] = tidy_takhrij(it["takhrij"])
        p = parts_of(it["text"])
        if p:
            it["parts"] = p
        refs = []
        for col in ("bukhari", "muslim") if sel not in REF_FIX else ():
            if cites(it.get("takhrij", ""), col):
                h = find_hadith(it["text"], col, stated_number(it["takhrij"], col))
                if h:
                    refs.append({"col": col, "n": h[0], "key": h[1]})
        for col, number, key in REF_FIX.get(sel, ()):
            assert any(n == number and key in t for n, t in SPLAIN[col]), (sel, number)
            assert key in plain(it["text"]), (sel, key)
            refs.append({"col": col, "n": number, "key": key})
        if refs:
            it["refs"] = refs
        if "takhrij" in it:
            g = grade(it["takhrij"])
            if g:
                it["grade"] = g
    ch["items"] = items
    chapters.append(ch)

assert fixed == {w for w, *_ in TEXT_FIX}, {w for w, *_ in TEXT_FIX} - fixed
meta = {
    "source": "حصن المسلم من أذكار الكتاب والسنة — د. سعيد بن علي بن وهف القحطاني",
    "urls": [ADHKAR_URL, NOTES_URL],
    "topics": [{"id": t[0], "title": t[1], "emoji": t[2]} for t in TOPICS],
    "chapters": chapters,
}
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
items = [it for c in chapters for it in c.get("items", [])]
print(len(chapters), "chapters,", len(items), "adhkar;", sum(1 for it in items if "takhrij" in it), "with takhrij;",
      sum(1 for c in chapters if "sources" in c), "chapters with chapter-level sources;",
      sum(len(it.get("refs", [])) for it in items), "Sahih refs;", sum(1 for it in items if "parts" in it), "with Qur'an")
