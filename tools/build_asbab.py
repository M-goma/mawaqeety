"""Builds mobile/assets/data/asbab.json: sahih asbab al-nuzul (occasions of revelation) found in the
bundled Sahih al-Bukhari and Sahih Muslim.

A narration is kept only when it explicitly states that a verse came down for an event
(«فنزلت», «فأنزل الله», «نزلت هذه الآية», «نزلت في», «أنزلت في» …) AND quotes that verse in {…},
and the quoted words match exactly one place in the Quran text (mobile/assets/data/quran.json).
Ambiguous or unmatched quotes are dropped; a hand-reviewed DROP list removes the remaining
false positives (verses quoted as an explanation, not as what came down for the event).

Output: {"v":1, "a":[{"s":surah,"f":from,"t":to,"c":"bukhari"|"muslim","n":number,"i":index,"x":excerpt}, …]}
"i" is the position in hadith_<c>.json.gz (Hadith.index in the app), "n" the hadith number.

Usage: python3 tools/build_asbab.py [--review]   (--review prints every kept/dropped candidate)
"""
import bisect, gzip, json, re, sys

DATA = 'mobile/assets/data'
REVIEW = '--review' in sys.argv

# --- normalisation (mirrors Arabic.searchKey in mobile/lib/core/arabic.dart) -------------------
MARKS = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
LETTERS = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي'})


def key(s, uthmani=False):
    """Letters only, no spaces, no alefs: the Uthmani script drops many alefs and writes
    الصلوٰة/الزكوٰة/الحيوٰة with a waw carrying a dagger alef, so that waw counts as an alef."""
    if uthmani:
        s = s.replace('وٰ', 'ا').replace('ۥ', '').replace('ۧ', 'ي')
        s = re.sub('ىٰ(?=[\u0621-\u064a])', 'ا', s)  # تَوَفَّىٰهُمُ = توفاهم
    s = MARKS.sub('', s).translate(LETTERS)
    s = re.sub('[^ء-ي]', '', s)
    # الليل is written ٱلَّيۡل in the mushaf: collapse doubled letters on both sides.
    return re.sub(r'(.)\1+', r'\1', s.replace('ا', '').replace('ء', ''))


def plain_map(t):
    """Diacritic-free text plus, for each kept character, its index in [t]."""
    out, idx = [], []
    for i, c in enumerate(t):
        if MARKS.match(c) or c in '‏‎':
            continue
        out.append(c.translate(LETTERS))
        idx.append(i)
    return ''.join(out), idx


# --- Quran stream -------------------------------------------------------------------------------
quran = json.load(open(f'{DATA}/quran.json', encoding='utf-8'))
stream, starts, refs = [], [], []  # starts[k] = offset of ayah refs[k] in the joined stream
pos = 0
for s in quran:
    for a, v in enumerate(s['v'], 1):
        k = key(v, uthmani=True)
        starts.append(pos); refs.append((s['n'], a)); stream.append(k); pos += len(k)
QS = ''.join(stream)


def ayah_at(p):
    return refs[bisect.bisect_right(starts, p) - 1]


def find_unique(k):
    """(start, end) of the only occurrence of [k] in the Quran, None if absent, 'many' if repeated."""
    # An occurrence that starts on the last letters of the previous ayah («…الكافرين * الذين…»
    # contains «ن الذين») is a stream artefact, not a real match.
    hits = []
    i = QS.find(k)
    while i >= 0:
        j = bisect.bisect_right(starts, i)
        nxt = starts[j] if j < len(starts) else len(QS)
        if nxt - i > 2 or i + len(k) <= nxt:
            hits.append(i)
        i = QS.find(k, i + 1)
    if not hits:
        return None
    return 'many' if len(hits) > 1 else (hits[0], hits[0] + len(k))


def locate(quote):
    """Maps a quoted verse to (surah, from, to). Tries the whole quote, then drops words from its
    end (narrators often cut a quote with «الآية» or paraphrase its tail). The surviving prefix must
    have ≥ 2 words and ≥ 7 letters and occur exactly once in the Quran."""
    quote = re.sub(r'\bان لا\b', 'الا', quote)  # «أن لا تقسطوا» is written «أَلَّا تُقۡسِطُواْ»
    words = [w for w in re.split(r'\s+', quote) if key(w)]
    # Narrators sometimes start the quote with «وَ»/«فَ» the mushaf has elsewhere: try with and without.
    # A trimmed prefix keeps at least half of the quote, so a short common opening («وإن خفتم أن»)
    # cannot stand in for a longer quote that is simply not found.
    for n in range(len(words), max(1, (len(words) - 1) // 2), -1):
        k = key(' '.join(words[:n]))
        if len(k) < 7:
            break
        for cand in (k, k[1:] if k[0] in 'وف' else None):
            if not cand:
                continue
            r = find_unique(cand)
            if r == 'many':
                return 'many'
            if r:
                (s1, a1), (s2, a2) = ayah_at(r[0]), ayah_at(r[1] - 1)
                if s1 != s2:
                    return None
                return s1, a1, a2
    return None


# --- triggers -----------------------------------------------------------------------------------
# In plain (diacritic-free, alef-unified) hadith text.
AFTER = re.compile(r'(فنزلت|فانزلت|فانزل الله|وانزل الله|فنزل القران|فانزل|نزلت هذه الايه|نزلت هذه الايات|نزلت هذه|'
                   r'انزلت هذه الايه|فيه نزلت|فيهم نزلت|فينا نزلت|في نزلت|فيها نزلت|نزلت فيه|نزلت في|انزلت في|انزلت فيه)')
QUOTE = re.compile(r'\{([^{}]+)\}')
UNTIL = re.compile(r'^[\s\.،,*-]*(الايه|الايات)?[\s\.،,]*(فقرا|وقرا|قرا)?\s*(الي قوله|الي|حتي بلغ|حتي|و)?\s*(تعالي)?[\s\.،,*]*$')

# Hand review (python3 tools/build_asbab.py --review): candidates whose quote is not the verse
# that came down for the event — e.g. the verse is cited as an explanation, or a different surah's
# verse is quoted in the same sentence. Keyed by (collection, hadith number, surah, from).
DROP = {
    ('bukhari', 4590, 4, 93),    # «هي آخر ما نزل»: chronology, not an occasion
    ('bukhari', 4766, 25, 68),   # «نزلت في أهل الشرك»: whom it concerns, no event
    ('muslim', 3023, 25, 68),
    ('bukhari', 1369, 14, 27),   # «نزلت في عذاب القبر»: the verse's meaning, no event
    ('muslim', 2871, 14, 27),
    ('bukhari', 45, 5, 3),       # Umar and the Jew: the day it came down, no occasion
    ('bukhari', 4407, 5, 3),
    ('bukhari', 4606, 5, 3),
    ('bukhari', 7268, 5, 3),
    ('muslim', 3017, 5, 3),
    ('bukhari', 4789, 33, 51),   # «بعد أن أنزلت»: practice after the verse
    ('bukhari', 4897, 62, 3),    # surah came down while they sat, then a question about it
    ('bukhari', 3317, 77, 1),    # where it came down (the cave), no occasion
    ('bukhari', 4930, 77, 1),
    ('bukhari', 4931, 77, 1),
    ('bukhari', 4934, 77, 1),
    ('bukhari', 1830, 77, 1),
    ('muslim', 2797, 96, 6),     # Muslim's narrator doubts whether this part is from Abu Hurayra
    ('bukhari', 4531, 2, 240),   # Mujahid's view on abrogation, not a companion's report of an event
    ('bukhari', 5344, 2, 240),
}

# Short quotes whose skeleton occurs in several places, resolved by hand from the narration's own
# context (cid, hadith number, quote as found) → (surah, from, to).
MANUAL = {
    ('bukhari', 773, 'قل اوحي الي'): (72, 1, 1),             # the jinn listening to the Quran
    ('bukhari', 1360, 'ما كان للنبي'): (9, 113, 113),         # death of Abu Talib
    ('bukhari', 1917, 'من الفجر'): (2, 187, 187),             # the white and black thread
    ('bukhari', 4511, 'من الفجر'): (2, 187, 187),
    ('muslim', 1091, 'من الفجر'): (2, 187, 187),
    ('bukhari', 2098, 'ليس عليكم جناح'): (2, 198, 198),       # trading in the Hajj season
    ('bukhari', 3855, 'الا من تاب وامن'): (25, 70, 70),       # «the one in al-Furqan»
    ('bukhari', 4567, 'لا يحسبن الذين يفرحون'): (3, 188, 188),
    ('bukhari', 4591, 'عرض الحياه الدنيا'): (4, 94, 94),     # «ولا تقولوا لمن ألقى إليكم السلام»
    ('bukhari', 4929, 'لا اقسم بيوم القيامه'): (75, 16, 17),  # «the verse in لا أقسم بيوم القيامة»: لا تحرك به لسانك
    ('bukhari', 5044, 'لا اقسم بيوم القيامه'): (75, 16, 17),
    ('bukhari', 7524, 'لا اقسم بيوم القيامه'): (75, 16, 17),
    ('muslim', 2778, 'واذ اخذ الله ميثاق الذين اوتوا الكتاب لتبيننه للناس ولا تكتمونه'): (3, 187, 188),
}



# «لما نزلت هذه الآية …» tells what people did AFTER a verse came down, not why it came down;
# «أول/آخر ما نزل», «آية نزلت في …», «سورة نزلت …» are about chronology. Skip triggers after these.
NOT_SABAB = re.compile(r'(?:^|\s)(لما|فلما|ولما|ايه|سوره|اخر|اول ما|ما|بعد ان|بعد ما)\s*$')


def excerpt(text, matn_start, a, b):
    """The matn around the occasion: from the narration start (or a sentence shortly before the
    trigger) to the end of the sentence holding the quote."""
    start = matn_start if 0 < matn_start <= a else (a if matn_start > a else 0)
    pre = ''
    if a - start > 650:
        # Start at a full stop 200–600 characters before the trigger, else at a comma.
        cut = text.rfind('.', a - 600, a - 200)
        if cut < 0:
            cut = text.rfind('،', a - 600, a - 200)
        start = cut + 1 if cut > 0 else a - 400
        pre = '… '
    stop = [i for i in (text.find('.', b), text.find('‏.', b)) if i > 0]
    end = min(stop) + 1 if stop and min(stop) - b < 250 else min(len(text), b + 200)
    post = '' if end >= len(text) - 2 else ' …'
    x = re.sub(r'\s+', ' ', text[start:end].replace('‏', '')).strip()
    return pre + x + post


def scan(cid):
    d = json.load(gzip.open(f'{DATA}/hadith_{cid}.json.gz'))
    out = []
    for i, (book, num, text, ms) in enumerate(d['h']):
        p, idx = plain_map(text)
        quotes = [(m.start(), m.end(), m.group(1)) for m in QUOTE.finditer(p)]
        if not quotes:
            continue
        found = {}  # (surah, from) → [to, span start, span end] (plain offsets)
        for t in AFTER.finditer(p):
            if NOT_SABAB.search(p[max(0, t.start() - 12):t.start()]):
                continue
            # Quote right after the trigger (≤ 60 chars), else for «نزلت في …» the quote just before it.
            q = next((x for x in quotes if 0 <= x[0] - t.end() <= 60), None)
            if q is None and 'في' in t.group(1):
                q = next((x for x in reversed(quotes) if 0 <= t.start() - x[1] <= 60), None)
            if q is None:
                continue
            loc = MANUAL.get((cid, num, q[2].strip())) or locate(q[2])
            if not isinstance(loc, tuple):
                if REVIEW:
                    print('UNMATCHED' if loc is None else 'AMBIGUOUS', cid, num, q[2][:80])
                continue
            s, f, to = loc
            # «{A} إلى قوله {B}»: extend the range to B when it is later in the same surah.
            last = q
            for nxt in quotes:
                if nxt[0] <= last[1]:
                    continue
                if UNTIL.match(p[last[1]:nxt[0]]):
                    l2 = locate(nxt[2])
                    if isinstance(l2, tuple) and l2[0] == s and l2[1] >= f and l2[2] - f <= 30:
                        to = max(to, l2[2]); last = nxt
                        continue
                break
            if (cid, num, s, f) in DROP:
                if REVIEW:
                    print('DROPPED', cid, num, s, f)
                continue
            a, b = min(t.start(), q[0]), max(t.end(), last[1])
            r = found.setdefault((s, f), [to, a, b])
            r[0], r[1], r[2] = max(r[0], to), min(r[1], a), max(r[2], b)
        for (s, f), (to, a, b) in found.items():
            x = excerpt(text, ms, idx[a], idx[b - 1] + 1)
            out.append({'s': s, 'f': f, 't': to, 'c': cid, 'n': num, 'i': i, 'x': x})
    return out


def grams(x):
    k = key(x)
    return {k[j:j + 5] for j in range(len(k) - 4)}


rows = scan('bukhari') + scan('muslim')
# Bukhari repeats a narration under several chapters, Muslim lists its variant chains under one
# number: keep one entry per hadith number and verse, and drop near-duplicate wordings of the same
# story (5-letter shingles overlapping by more than half).
uniq, seen = [], set()
for r in rows:
    k = (r['c'], r['n'], r['s'], r['f'])
    if k in seen:
        continue
    g = grams(r['x'])
    if any(u['c'] == r['c'] and u['s'] == r['s'] and u['f'] == r['f'] and len(g & u['g']) > 0.5 * min(len(g), len(u['g'])) for u in uniq):
        continue
    seen.add(k)
    r['g'] = g
    uniq.append(r)
for r in uniq:
    del r['g']
uniq.sort(key=lambda r: (r['s'], r['f'], r['t'], r['c'] != 'bukhari', r['n']))
if REVIEW:
    for r in uniq:
        x = MARKS.sub('', r['x'])
        print(f"{r['s']}:{r['f']}-{r['t']} {r['c']} {r['n']} | {x[-230:]}")
print(len(rows), 'candidates,', len(uniq), 'kept,', len({r['s'] for r in uniq}), 'surahs', file=sys.stderr)
with open(f'{DATA}/asbab.json', 'w', encoding='utf-8') as fp:
    json.dump({'v': 1, 'a': uniq}, fp, ensure_ascii=False, separators=(',', ':'))
