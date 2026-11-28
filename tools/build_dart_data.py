"""Converts the content kept as Dart constants in the mobile app into JSON for the desktop app.

    python3 tools/build_dart_data.py

Reads (from mobile/lib/data):
  nasab.dart            -> src/Mawaqeety.Core/Resources/nasab.json
  companions_islam.dart -> src/Mawaqeety.Core/Resources/companions_islam.json
  atlas.dart            -> src/Mawaqeety.Core/Resources/atlas.json

The Dart `const` declarations are turned into Python expressions (strings are copied verbatim,
adjacent literals concatenated, named arguments mapped) and evaluated with one function per Dart
constructor, so the text is never retyped. Re-run after editing the Dart files.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'mobile', 'lib', 'data')
OUT = os.path.join(ROOT, 'src', 'Mawaqeety.Core', 'Resources')


def to_python(code: str) -> str:
    """Dart expression -> Python expression (strings untouched)."""
    out, i, n = [], 0, len(code)
    chunk = []

    def flush():
        s = ''.join(chunk)
        chunk.clear()
        s = re.sub(r'\bconst\s+', '', s)
        s = re.sub(r'<\w+>\s*\[', '[', s)  # typed list literal
        s = re.sub(r'\btrue\b', 'True', s)
        s = re.sub(r'\bfalse\b', 'False', s)
        s = re.sub(r'\bnull\b', 'None', s)
        s = re.sub(r'\bAtlasCertainty\.(\w+)', r"'\1'", s)
        s = re.sub(r'\b(\w+)\s*:(?!:)', r'\1=', s)  # named argument
        s = re.sub(r'\bNasab\.(\w+)', r'\1', s)
        out.append(s)

    while i < n:
        c = code[i]
        if code.startswith('//', i):
            j = code.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in '\'"':
            if '$' in code[i:code.find(c, i + 1) + 1]:
                raise ValueError('string interpolation is not supported')
            flush()
            j = i + 1
            while code[j] != c:
                j += 2 if code[j] == '\\' else 1
            out.append(code[i:j + 1])
            i = j + 1
            continue
        chunk.append(c)
        i += 1
    flush()
    return ''.join(out)


def declarations(src: str):
    """Yields (name, dart expression) for each `const name = ...;` (static or top-level)."""
    for m in re.finditer(r'(?:static\s+)?const\s+(\w+)\s*=\s*', src):
        i, depth = m.end(), 0
        while True:
            c = src[i]
            if c in '\'"':
                j = i + 1
                while src[j] != c:
                    j += 2 if src[j] == '\\' else 1
                i = j + 1
                continue
            if src.startswith('//', i):
                i = src.index('\n', i)
                continue
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            elif c == ';' and depth == 0:
                yield m.group(1), src[m.end():i]
                break
            i += 1


def record(*fields, **defaults):
    def make(*args, **kw):
        order = list(fields) + list(defaults)  # optional positional parameters follow the required ones
        if len(args) > len(order):
            raise TypeError(f'too many arguments: {args}')
        d = dict(defaults)
        d.update(zip(order, args))
        for k, v in kw.items():
            if k not in fields and k not in defaults:
                raise TypeError(f'unknown named argument {k}')
            d[k] = v
        missing = [f for f in fields if f not in d]
        if missing:
            raise TypeError(f'missing {missing}')
        return d
    return make


def evaluate(path, ctors):
    with open(path, encoding='utf-8') as f:
        src = f.read()
    env = dict(ctors)
    result = {}
    for name, expr in declarations(src):
        value = eval('(' + to_python(expr) + ')', {'__builtins__': {}}, env)  # noqa: S307 (our own repository files)
        env[name] = value
        result[name] = value
    return result


def write(name, data):
    path = os.path.join(OUT, name)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{path}: {os.path.getsize(path)} bytes')


def main():
    # النسب الشريف
    n = evaluate(os.path.join(SRC, 'nasab.dart'), {
        'NasabSource': record('label', 'url'),
        'Ancestor': record('name', note=None),
        'CompanionNasab': record('id', 'name', 'clan', 'chain', 'meet', 'source', remark=None),
    })
    chain = n['chain']
    for c in n['companions']:
        assert chain[c['meet']]['name'] == c['chain'][-1], (c['id'], c['meet'])
    write('nasab.json', {k: n[k] for k in ['intro', 'agreed', 'mother', 'bukhariRef', 'fath', 'zad', 'motherSource',
                                          'chain', 'companions', 'sources']})

    # كيف أسلم الصحابة
    c = evaluate(os.path.join(SRC, 'companions_islam.dart'), {
        'IslamSource': record('label', 'url'),
        'IslamHadith': record('text', 'number'),
        'CompanionIslam': record('id', 'name', 'by', 'story', 'sources', age=None, ageDisputed=False, hadith=None),
    })
    assert len(c['list']) == 10
    write('companions_islam.json', {k: c[k] for k in ['intro', 'footnote', 'list']})

    # أطلس قصص الأنبياء
    a = evaluate(os.path.join(SRC, 'atlas.dart'), {
        'AtlasPlace': record('name', 'lat', 'lng', 'prophets', 'note', 'source', 'certainty'),
    })
    write('atlas.json', {'places': a['atlasPlaces']})


if __name__ == '__main__':
    sys.exit(main())
