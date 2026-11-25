"""Splits each prophet story into narration chunks (same order the app reads them)."""
import json, sys

LIMIT = 2400
p = sorted(json.load(open('mobile/assets/data/prophets.json')), key=lambda x: x['order'])
out = []
for x in p:
    parts = [f"{x['nameAr']}. {x['title']}. {x['summary']}"]
    for s in x.get('sections', []):
        paras = s['body'].split('\n\n')
        parts.append(f"{s['heading']}. {paras[0]}")
        parts += paras[1:]
    if x.get('lessons'):
        parts.append('دروس وعبر. ' + ' '.join(x['lessons']))
    chunks, cur = [], ''
    for part in parts:
        if cur and len(cur) + len(part) + 1 > LIMIT:
            chunks.append(cur); cur = part
        else:
            cur = (cur + '\n' + part) if cur else part
    if cur: chunks.append(cur)
    out.append({'id': x['id'], 'order': x['order'], 'chunks': chunks})
json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
print(sum(len(c) for o in out for c in o['chunks']), sum(len(o['chunks']) for o in out))
