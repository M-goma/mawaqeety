"""Builds mobile/assets/data/tafsir_muyassar.json.gz from spa5k/tafsir_api (التفسير الميسر,
مجمع الملك فهد لطباعة المصحف الشريف). Output: {"name":..., "t":[[ayah texts of surah 1], ...]}."""
import gzip, json, re, sys, urllib.request, concurrent.futures as cf

BASE = 'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/ar-tafsir-muyassar/{}.json'
out = sys.argv[1] if len(sys.argv) > 1 else 'mobile/assets/data/tafsir_muyassar.json.gz'

def fetch(n):
    for _ in range(4):
        try:
            with urllib.request.urlopen(BASE.format(n), timeout=60) as r:
                return n, json.load(r)
        except Exception:
            pass
    raise SystemExit(f'failed {n}')

def clean(t):
    # Drop the surah intro (name, aims) kept before "[التفسير]" on the first ayah.
    if '[التفسير]' in t:
        t = t.split('[التفسير]', 1)[1]
    return re.sub(r'\n{2,}', '\n', t).strip()

with cf.ThreadPoolExecutor(8) as ex:
    data = dict(ex.map(fetch, range(1, 115)))
t = []
for n in range(1, 115):
    rows = sorted(data[n], key=lambda r: r['ayah'])
    t.append([clean(r['text']) for r in rows])
quran = json.load(open('mobile/assets/data/quran.json', encoding='utf-8'))
for s, v in zip(quran, t):
    assert len(s['v']) == len(v), (s['n'], len(s['v']), len(v))
with gzip.open(out, 'wt', encoding='utf-8', compresslevel=9) as f:
    json.dump({'name': 'التفسير الميسر', 'src': 'مجمع الملك فهد لطباعة المصحف الشريف', 't': t}, f, ensure_ascii=False, separators=(',', ':'))
print('ok', sum(map(len, t)))
