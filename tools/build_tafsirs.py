"""Builds the extra tafsirs and word meanings shown in the ayah sheet, next to التفسير الميسر (tools/build_tafsir.py).

Source: spa5k/tafsir_api, pinned to tag v1.2.3 (MIT), which exports the Quranic Universal Library (QUL, Tarteel:
https://qul.tarteel.ai/resources/tafsir) as one JSON file per surah. Nothing is written or reworded here: texts are
copied as they are, only regrouped by ayah range and with PDF line breaks joined.

  mobile/assets/data/tafsir_saadi.json.gz      تيسير الكريم الرحمن (تفسير السعدي)        QUL 308 (ar-tafsir-as-saadi)
  mobile/assets/data/tafsir_mukhtasar.json.gz  المختصر في تفسير القرآن الكريم (مركز تفسير)  QUL 251 (ar-tafsir-al-mukhtasar)
  mobile/assets/data/gharib_muyassar.json.gz   الميسر في غريب القرآن الكريم (مجمع الملك فهد) QUL 519 (al-muyassar-fi-al-gharib)

Tafsir files: {"name", "book", "author", "src", "via", "s": [per surah: [[from, to, text], ...]]}: the sections cover
every ayah of the surah once, in order (a section of several ayat is the book's own grouping).
Word meanings: {"name", "src", "via", "w": [per surah: [per ayah: [[word, count, phrase, meaning], ...]]]}: «word» is
the 0-based index of the phrase's first word in the ayah text of quran.json and «count» its number of words
(word = -1 when the phrase was not found in the ayah: the sheet then lists it without highlighting it).

Run from the repo root: python3 tools/build_tafsirs.py
"""
import concurrent.futures as cf
import gzip
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


# ─────────────── السعدي: QUL groups a passage's ayat under one text; the book marks each part «{n}» or «{n ـ m}».
MARK = re.compile(r'\{\s*(\d+)\s*(?:[ـ\-–]\s*(\d+)\s*)?\}')


def clean_saadi(t):
    paras = [' '.join(p.split()) for p in re.split(r'\n\s*\n', t.replace('\r', ''))]  # single \n = printed line break
    return '\n'.join(p for p in paras if p and not re.fullmatch(r'[*\s]+', p))


def saadi_sections(n, rows, count):
    groups = []  # [[ayat], text] in order
    for r in rows:
        if groups and groups[-1][1] == r['text']:
            groups[-1][0].append(r['ayah'])
        else:
            groups.append([[r['ayah']], r['text']])
    owner, text = {}, {}
    for ayat, txt in groups:
        ms = list(MARK.finditer(txt))
        parts = [(int(m[1]), int(m[2] or m[1]), txt[m.end():ms[i + 1].start() if i + 1 < len(ms) else len(txt)])
                 for i, m in enumerate(ms)]
        pre = txt[:ms[0].start()] if ms else txt  # the surah's intro («وهي مكية») or a group without markers
        if not parts:
            parts = [(ayat[0], ayat[-1], pre)]
        elif pre.strip():
            a, b, x = parts[0]
            parts[0] = (min(a, ayat[0]), b, pre.rstrip() + '\n\n' + x)
        keys = []
        for a, b, x in parts:
            k = len(text)
            text[k] = x
            keys.append((a, b, k))
        for ay in ayat:
            if ay in owner:
                continue
            hit = [k for a, b, k in keys if a <= ay <= b]
            # An ayah without its own marker (e.g. «الرحمن الرحيم» after the basmala) belongs to the part before it.
            owner[ay] = hit[0] if hit else ([k for a, b, k in keys if a <= ay] or [keys[0][2]])[-1]
    out = []
    for ay in range(1, count + 1):
        k = owner[ay]
        if out and out[-1][3] == k:
            out[-1][1] = ay
        else:
            out.append([ay, ay, clean_saadi(text[k]), k])
    assert len({o[3] for o in out}) == len(out), (n, 'a part split in two')
    return [o[:3] for o in out]


def build_saadi():
    data = fetch_all('ar-tafsir-as-saadi')
    s = [saadi_sections(q['n'], data[q['n']], len(q['v'])) for q in quran]
    check_sections(s)
    write('tafsir_saadi.json.gz', {
        'name': 'تفسير السعدي', 'book': 'تيسير الكريم الرحمن في تفسير كلام المنان',
        'author': 'عبد الرحمن بن ناصر السعدي (ت ١٣٧٦هـ)', 'src': 'تيسير الكريم الرحمن في تفسير كلام المنان، للشيخ عبد الرحمن بن ناصر السعدي',
        'via': VIA.format(308), 's': s})
    return sum(map(len, s))


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


def build_gharib():
    data = fetch_all('al-muyassar-fi-al-gharib')
    w, found, total = [], 0, 0
    for q in quran:
        rows = {r['ayah']: r['text'] for r in data[q['n']]}
        surah = []
        for a, verse in enumerate(q['v'], 1):
            words = [key(x) for x in verse.split()]
            items = []
            t = rows.get(a, '')
            entries = ENTRY.findall(t.strip())
            assert len(entries) == t.count('﴿'), (q['n'], a)
            for phrase, meaning in entries:
                phrase = re.sub(r'[ ⁠]', '', phrase).strip()
                i, n = locate(words, phrase)
                total += 1
                found += i >= 0
                items.append([i, n, phrase, ' '.join(meaning.split())])
            surah.append(items)
        w.append(surah)
    write('gharib_muyassar.json.gz', {
        'name': 'الميسر في غريب القرآن الكريم', 'src': 'مجمع الملك فهد لطباعة المصحف الشريف',
        'via': VIA.format(519), 'w': w})
    return total, found


if __name__ == '__main__':
    print('saadi sections', build_saadi())
    print('mukhtasar sections', build_mukhtasar())
    print('gharib entries / located in the ayah', build_gharib())
