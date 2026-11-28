"""Builds the extra tafsirs and word meanings shown in the ayah sheet, next to التفسير الميسر (tools/build_tafsir.py).

Source: spa5k/tafsir_api, pinned to tag v1.2.3 (MIT), which exports the Quranic Universal Library (QUL, Tarteel:
https://qul.tarteel.ai/resources/tafsir) as one JSON file per surah. Nothing is written or reworded here: texts are
copied as they are, only regrouped by ayah range. (تفسير السعدي is built from islamweb: tools/build_tafsir_saadi.py.)

  mobile/assets/data/tafsir_mukhtasar.json.gz  المختصر في تفسير القرآن الكريم (مركز تفسير)  QUL 251 (ar-tafsir-al-mukhtasar)
  mobile/assets/data/gharib_muyassar.json.gz   الميسر في غريب القرآن الكريم (مجمع الملك فهد) QUL 519 (al-muyassar-fi-al-gharib)

Tafsir files: {"name", "book", "author", "src", "via", "s": [per surah: [[from, to, text], ...]]}: the sections cover
every ayah of the surah once, in order (a section of several ayat is the book's own grouping).
Word meanings: {"name", "src", "via", "w": [per surah: [per ayah: [[word, count, phrase, meaning], ...]]]}: «word» is
the 0-based index of the phrase's first word in the ayah text of quran.json and «count» its number of words
(word = -1 when the phrase was not found in the ayah: the sheet then lists it without highlighting it).
Two copies of الميسر في غريب القرآن circulate and differ in places (e.g. 2:6), and the Complex's own site could not be
reached to settle it: only the entries on which QUL's copy and the KFGQPC copy shipped by nresan/warattil
(android/app/src/main/assets/ghareeb.json, pinned by its SHA-256 below) agree — same words, same meaning, ignoring
tashkeel and punctuation — are kept.

Run from the repo root: python3 tools/build_tafsirs.py
"""
import concurrent.futures as cf
import gzip
import hashlib
import json
import re
import unicodedata
import urllib.request

TAG = 'v1.2.3'
BASE = 'https://raw.githubusercontent.com/spa5k/tafsir_api/' + TAG + '/tafsir/{}/{}.json'
VIA = 'spa5k/tafsir_api ' + TAG + ' (QUL, Tarteel: qul.tarteel.ai/resources/tafsir/{})'
OUT = 'mobile/assets/data/'
quran = json.load(open(OUT + 'quran.json', encoding='utf-8'))


def fetch_all(slug):
    def one(n):
        for _ in range(4):
            try:
                with urllib.request.urlopen(BASE.format(slug, n), timeout=60) as r:
                    return n, sorted(json.load(r), key=lambda x: x['ayah'])
            except Exception:
                pass
        raise SystemExit(f'failed {slug} {n}')
    with cf.ThreadPoolExecutor(8) as ex:
        return dict(ex.map(one, range(1, 115)))


def write(name, obj):
    with gzip.open(OUT + name, 'wt', encoding='utf-8', compresslevel=9) as f:
        json.dump(obj, f, ensure_ascii=False, separators=(',', ':'))


def check_sections(s):
    for surah, secs in zip(quran, s):
        n = len(surah['v'])
        at = 1
        for a, b, t in secs:
            assert a == at and b >= a and t.strip(), (surah['n'], a, b)
            at = b + 1
        assert at == n + 1, (surah['n'], at, n)


# ─────────────── المختصر: consecutive ayat with the same text are one section (the book explains them together).
def build_mukhtasar():
    data = fetch_all('ar-tafsir-al-mukhtasar')
    s = []
    for q in quran:
        rows = {r['ayah']: r['text'].strip() for r in data[q['n']]}
        secs = []
        for a in range(1, len(q['v']) + 1):
            if secs and secs[-1][2] == rows[a]:
                secs[-1][1] = a
            else:
                secs.append([a, a, rows[a]])
        s.append(secs)
    check_sections(s)
    write('tafsir_mukhtasar.json.gz', {
        'name': 'المختصر في التفسير', 'book': 'المختصر في تفسير القرآن الكريم',
        'author': 'جماعة من علماء التفسير، إصدار مركز تفسير للدراسات القرآنية', 'src': 'مركز تفسير للدراسات القرآنية',
        'via': VIA.format(251), 's': s})
    return sum(map(len, s))


# ─────────────── الميسر في غريب القرآن: «﴿phrase﴾: meaning» entries separated by blank lines.
ENTRY = re.compile(r'﴿([^﴾]+)﴾\s*:\s*(.+?)(?=\n\s*\n\s*﴿|\Z)', re.S)
HAMZA = str.maketrans({'أ': 'ء', 'إ': 'ء', 'آ': 'ء', 'ؤ': 'ء', 'ئ': 'ء', 'ٱ': 'ا', 'ى': 'ي'})


def key(word):
    """A word's letters only (no tashkeel, pause marks, tatweel; one hamza; ٱ = ا), to find a phrase in the ayah."""
    w = unicodedata.normalize('NFKC', word).translate(HAMZA)
    w = w.replace('ٔ', 'ء').replace('ٕ', 'ء')
    w = re.sub(r'[^ء-ي]', '', w)
    return w.replace('ـ', '').replace('ا', '')  # tatweel; Uthmani writes many alefs as a dagger alef or not at all


def locate(words, phrase):
    p = [k for k in map(key, phrase.split()) if k]
    if not p:
        return -1, 0
    for i in range(len(words) - len(p) + 1):
        if words[i:i + len(p)] == p:
            return i, len(p)
    for i in range(len(words) - len(p) + 1):  # the phrase may leave out a leading «و»/«ف» («بَرًّا» for «وَبَرًّا»)
        w = words[i]
        if w[:1] in 'وف' and w[1:] == p[0] and words[i + 1:i + len(p)] == p[1:]:
            return i, len(p)
    return -1, len(p)


WARATTIL = 'https://raw.githubusercontent.com/nresan/warattil/main/android/app/src/main/assets/ghareeb.json'
WARATTIL_SHA256 = 'c5b02f7009100f625bc8fc3e16f7208c3fe58754ea2d7bfec96983ecf54eb1cb'


def letters(s):
    """Only the letters: no tashkeel, tatweel, Quranic marks, punctuation or spaces."""
    s = unicodedata.normalize('NFKC', s).replace('\u0671', '\u0627')
    return re.sub(r'[^\u0621-\u063A\u0641-\u064A]', '', s)


def build_gharib():
    data = fetch_all('al-muyassar-fi-al-gharib')
    raw = urllib.request.urlopen(WARATTIL, timeout=120).read()
    assert hashlib.sha256(raw).hexdigest() == WARATTIL_SHA256, 'the second copy changed: review it before rebuilding'
    other = {k: {letters(p): letters(m) for p, m in v} for k, v in json.loads(raw).items()}
    w, total, kept, found, ayat = [], 0, 0, 0, 0
    for q in quran:
        rows = {r['ayah']: r['text'] for r in data[q['n']]}
        surah = []
        for a, verse in enumerate(q['v'], 1):
            words = [key(x) for x in verse.split()]
            items = []
            t = rows.get(a, '')
            entries = ENTRY.findall(t.strip())
            assert len(entries) == t.count('\ufd3f'), (q['n'], a)
            agree = other.get(f"{q['n']}:{a}", {})
            for phrase, meaning in entries:
                phrase = re.sub(r'[\u200a\u2060]', '', phrase).strip()
                total += 1
                if agree.get(letters(phrase)) != letters(meaning):
                    continue  # the two copies differ here (or only one has it): left out
                i, n = locate(words, phrase)
                kept += 1
                found += i >= 0
                items.append([i, n, phrase, ' '.join(meaning.split())])
            ayat += bool(items)
            surah.append(items)
        w.append(surah)
    write('gharib_muyassar.json.gz', {
        'name': 'الميسر في غريب القرآن الكريم', 'src': 'مجمع الملك فهد لطباعة المصحف الشريف',
        'via': VIA.format(519) + '؛ يُعرض فقط ما اتفقت عليه نسختان: QUL و nresan/warattil', 'w': w})
    return {'entries in QUL': total, 'kept (both copies agree)': kept, 'ayat with meanings': ayat,
            'kept and placed on their words': found}


if __name__ == '__main__':
    print('mukhtasar sections', build_mukhtasar())
    print('gharib', build_gharib())
