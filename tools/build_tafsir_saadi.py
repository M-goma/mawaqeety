"""Builds mobile/assets/data/tafsir_saadi.json.gz (تفسير السعدي) from islamweb.net's library, book 209:
https://www.islamweb.net/ar/library/content/209/<id> — «تيسير الكريم الرحمن في تفسير كلام المنان»,
عبد الرحمن بن ناصر السعدي، دار ابن الجوزي. Content pages 1–1747 are the tafsir (1748–1762: the appendix of the
variants of «النسخة ب», not used).

The pages are fetched politely (one at a time, a pause between requests, retries) into a cache folder, then parsed.
Nothing is reworded: the text is the page's plain text (islamweb's links, tooltips and «[ص: n]» page numbers removed).

Each page lists the ayat it explains (its header), then the commentary; the book marks the part about each ayah
«(n)» or «(n - m)». A section is one such part — or the whole passage when it has no markers. Output:
{"name", "book", "author", "src", "via", "url", "s": [per surah: [[from, to, text, [page ids]], ...]]}; the islamweb
URL of a section is "url" with {} = its first page id (https://www.islamweb.net/ar/library/content/209/<page id>). Ayat islamweb lists without commentary are
reported and left without a section (no other edition is mixed in); any other gap fails the build unless --allow-gaps.

  python3 tools/build_tafsir_saadi.py --cache /some/dir           # fetch (≈ 1747 pages) and build
  python3 tools/build_tafsir_saadi.py --cache /some/dir --fetch-only
"""
import argparse
import gzip
import html
import json
import os
import re
import sys
import time
import urllib.request

BOOK, LAST = 209, 1747
URL = 'https://www.islamweb.net/ar/library/content/209/{}'
OUT = 'mobile/assets/data/'


def fetch(cache, pid, delay):
    p = os.path.join(cache, f'{pid}.html')
    if os.path.exists(p) and os.path.getsize(p) > 5000:
        return False
    req = urllib.request.Request(URL.format(pid), headers={'User-Agent': 'Mozilla/5.0 (compatible; tafsir-build)'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            if b"id='pagebody'" not in data:
                raise ValueError('no page body')
            with open(p + '.tmp', 'wb') as f:
                f.write(data)
            os.replace(p + '.tmp', p)
            return True
        except Exception as e:  # noqa: BLE001
            print(f'page {pid}: {e} (retry {attempt + 1})', file=sys.stderr)
            time.sleep(delay * (attempt + 2) * 2)
    raise SystemExit(f'failed page {pid}')


AYAH = re.compile(r"<span class=\"quranatt\" style='display:none'>nindex\.php\?page=tafseer&surano=(\d+)&ayano=(\d+)</span>")
# A header ayah: a «mainsubj» span that holds one linked ayah and nothing else.
PAGE_NO = re.compile(r'<font[^>]*>\s*\[\s*<font[^>]*>\s*ص:\s*</font>\s*\d+\s*\]\s*</font>')  # «[ص: n]»
# A header ayah: a linked ayah, usually wrapped in a «mainsubj» span (subject index), then spaces/&nbsp;.
HEAD_ITEM = re.compile(
    r'(?:<span class="mainsubj"><span class="mainsubjatt"\s+style=\'display:none\'>[^<]*</span>)?'
    r'<a [^>]*><span class="quran"><span class="quranatt" style=\'display:none\'>'
    r'nindex\.php\?page=tafseer&surano=(\d+)&ayano=(\d+)</span>[^<]*</span></a>\s*(?:</span>)?(?:&nbsp;|\s)*')
# A header: a run of such ayat that ends its paragraph («<br>»). Runs inside the commentary (quotes) are told apart
# below: a header holds a «mainsubj» ayah or opens the page.
HEAD = re.compile(r'(?:' + HEAD_ITEM.pattern + r')+(?=[.:،\s]*(?:<br|\(\d))')


def page_body(t):
    i = t.find("id='pagebody'")
    j = t.find("id='pagebody_thaskeel'", i)
    b = t[t.find('>', i) + 1:t.rfind('<div', i, j)]
    b = re.sub(r'onclick="[^"]*"', '', b)
    b = PAGE_NO.sub(' ', b)
    return b.replace('<span class="hashiya_title"></span>', '')


RUN = re.compile(r'(?:' + HEAD_ITEM.pattern + r')+')


def headers(b):
    """The page's first run of linked ayat is its header (text before it is a title or lead-in, never a link).
    Later passages on the same page start with a run that holds a «mainsubj» ayah and ends its paragraph."""
    first = RUN.search(b)
    if not first:
        return []
    out = [first]
    for m in HEAD.finditer(b, first.end()):
        if 'class="mainsubj"' in m.group(0):
            out.append(m)
    return out


def to_text(b):
    # Quoted Quran (islamweb shows it in colour) is marked ﴿…﴾ so it stays distinct from the commentary.
    b = re.sub(r"<span class=\"quran\"><span class=\"quranatt\" style='display:none'>[^<]*</span>([^<]*)</span>",
               lambda m: '﴿' + m[1].strip() + '﴾', b)
    b = re.sub(r'<span [^>]*style=["\']display:\s*none["\'][^>]*>[^<]*</span>', '', b)  # islamweb's hidden link data
    b = re.sub(r'<font[^>]*>\s*\[\s*<font[^>]*>\s*ص:\s*</font>\s*\d+\s*\]\s*</font>', ' ', b)  # printed page number
    b = re.sub(r'<br\s*/?>', '\n', b)
    b = re.sub(r'<[^>]+>', '', b)
    x = html.unescape(b).replace('\xa0', ' ')
    x = re.sub(r'(?<=[\u0621-\u064A])﴿', ' ﴿', x)  # islamweb sometimes glues a word to the quote («أنهلم يلد»)
    x = re.sub(r'﴾(?=[\u0621-\u064A])', '﴾ ', x)
    x = re.sub(r'\[\s*ص:\s*\d+\s*\]', ' ', x)
    lines = [' '.join(l.split()) for l in x.split('\n')]
    x = '\n'.join(l for l in lines if l)
    x = re.sub(r' ([،؛:.,)\]»؟!])', r'\1', x)  # islamweb puts a space before punctuation after linked words
    return x.strip()


MARK = re.compile(r'^\((\d+)\s*(?:[-–ـ]\s*(\d+))?\)\s*', re.M)


def intro(line):
    """A surah's short intro line: «وهي مكية»، «وهي مدنية، وقيل: مكية»، «ويقال: سورة التوبة»."""
    return len(line) <= 60 and ('مكية' in line or 'مدنية' in line or line.startswith('ويقال: سورة'))


DROPPED = []  # (page, text) left out before a page's first header: front matter or a lead-in to the header ayah


def passages(pid, t):
    """[(surah, [ayat], text)] for one page: each header (list of ayat) starts a passage."""
    b = page_body(t)
    heads = headers(b)
    out = []
    if not heads:
        return out
    # Before the first header: the surah's title, the basmala, «وهي مكية» (kept with the first passage), or front
    # matter / a lead-in like «وقوله» to the header ayah (left out, and listed by the build).
    pre = []
    for l in to_text(b[:heads[0].start()]).split('\n'):
        if not l or l.startswith('تفسير ') or l == 'بسم الله الرحمن الرحيم':
            continue
        if intro(l):
            pre.append(l)
        else:
            DROPPED.append((pid, l))
    for i, h in enumerate(heads):
        ayat = [(int(s), int(a)) for s, a in HEAD_ITEM.findall(h.group(0))]
        surahs = {s for s, _ in ayat}
        assert len(surahs) == 1, (pid, ayat)
        end = heads[i + 1].start() if i + 1 < len(heads) else len(b)
        text = re.sub(r'^[.:،\s]+', '', to_text(b[h.end():end]))
        if i == 0 and pre:
            text = '\n'.join(pre) + '\n' + text
        out.append((ayat[0][0], [a for _, a in ayat], text))
    return out


def sections_of(pid, surah, ayat, text):
    """Split a passage at the book's «(n)» / «(n - m)» markers."""
    ms = list(MARK.finditer(text))
    if not ms:
        return [(ayat[0], ayat[-1], text)]
    parts = []
    pre = text[:ms[0].start()].strip()
    for i, m in enumerate(ms):
        a, b = int(m[1]), int(m[2] or m[1])
        parts.append([a, b, text[m.end():ms[i + 1].start() if i + 1 < len(ms) else len(text)].strip()])
    if pre:
        parts[0][2] = pre + '\n' + parts[0][2]
    parts[0][0] = min(parts[0][0], ayat[0])
    parts[-1][1] = max(parts[-1][1], ayat[-1])
    # An ayah in the header without a marker of its own belongs to the part before it.
    for i in range(len(parts) - 1):
        parts[i][1] = max(parts[i][1], parts[i + 1][0] - 1)
    return [tuple(p) for p in parts]


def merge(parts):
    """Sections in page order -> non-overlapping sections. islamweb sometimes splits one ayah over two pages (the
    end of 2:219 is explained with 2:220): parts that share an ayah are joined, in order, into one section."""
    out = []
    for a, b, x, pid in parts:
        if out and a <= out[-1][1]:
            last = out[-1]
            last[1] = max(last[1], b)
            last[2] += '\n' + x
            if pid not in last[3]:
                last[3].append(pid)
        else:
            out.append([a, b, x, [pid]])
    return out


def build(cache, allow_gaps):
    quran = json.load(open(OUT + 'quran.json', encoding='utf-8'))
    per = {q['n']: [] for q in quran}  # surah -> [(from, to, text, page)] in page order
    empty = []  # (surah, from, to, page): a header with no commentary on islamweb
    for pid in range(1, LAST + 1):
        t = open(os.path.join(cache, f'{pid}.html'), encoding='utf-8', errors='replace').read()
        ps = passages(pid, t)
        assert ps, f'page {pid}: no ayah header'
        for surah, ayat, text in ps:
            if not text:  # islamweb lists the ayat but gives no commentary for them
                empty.append((surah, ayat[0], ayat[-1], pid))
                continue
            for a, b, x in sections_of(pid, surah, ayat, text):
                assert x, (pid, surah, a)
                per[surah].append((a, b, x, pid))
    s, gaps, problems, joined = [], [], [], 0
    for q in quran:
        n, count = q['n'], len(q['v'])
        secs = merge(per[n])
        joined += len(per[n]) - len(secs)
        out, at = [], 1
        for a, b, x, pids in secs:
            if a < at or b > count:
                problems.append((n, a, b, pids))
                continue
            if a > at:
                gaps.append((n, at, a - 1))
            out.append([a, b, x, pids])
            at = b + 1
        if at <= count:
            gaps.append((n, at, count))
        s.append(out)
    covered = sum(o[1] - o[0] + 1 for surah in s for o in surah)
    print('sections', sum(map(len, s)), 'ayat covered', covered, 'of', sum(len(q['v']) for q in quran),
          '; parts joined because they share an ayah:', joined)
    expected = {(n, a, b) for n, a, b, _ in empty}
    for n, a, b, pid in empty:
        print(f'no commentary on islamweb (page {pid}): {n}:{a}-{b} — left without tafsir')
    gaps = [g for g in gaps if g not in expected]
    for g in gaps:
        print('not on islamweb:', g)
    for p in problems:
        print('out of order / out of range (left out):', p)
    for pid, l in DROPPED:
        print(f'left out (page {pid}, before its first ayah header): {l[:120]}')
    if (gaps or problems) and not allow_gaps:
        raise SystemExit('gaps or overlaps: see above')
    with gzip.open(OUT + 'tafsir_saadi.json.gz', 'wt', encoding='utf-8', compresslevel=9) as f:
        json.dump({'name': 'تفسير السعدي', 'book': 'تيسير الكريم الرحمن في تفسير كلام المنان',
                   'author': 'عبد الرحمن بن ناصر السعدي (ت ١٣٧٦هـ)',
                   'src': 'تيسير الكريم الرحمن في تفسير كلام المنان، للشيخ عبد الرحمن بن ناصر السعدي',
                   'via': 'islamweb.net، المكتبة الإسلامية، الكتاب ٢٠٩ (دار ابن الجوزي)',
                   'url': URL.format('{}'), 's': s}, f, ensure_ascii=False, separators=(',', ':'))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', required=True)
    ap.add_argument('--delay', type=float, default=1.0)
    ap.add_argument('--fetch-only', action='store_true')
    ap.add_argument('--allow-gaps', action='store_true')
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)
    for pid in range(1, LAST + 1):
        if fetch(args.cache, pid, args.delay):
            time.sleep(args.delay)
        if pid % 100 == 0:
            print('fetched', pid, flush=True)
    if not args.fetch_only:
        build(args.cache, args.allow_gaps)
