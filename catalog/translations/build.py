"""Translation tooling for the 100 selected lessons.

  python3 build.py extract          writes source/<slug>.json (translatable strings only);
                                    source/meta.json (titles, artists, museums, movements) is exported from the database
  python3 build.py check <lang>     checks <lang>/lessons/*.json and <lang>/meta.json against the English source
  python3 build.py merge <lang>     writes build/<lang>/<slug>.json: translated text + English coordinates
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CATALOG = os.path.dirname(HERE)
LANGS = ('fr', 'it', 'es', 'de')
SLUGS = open(os.path.join(HERE, 'selection.txt')).read().split()
ITEM_TEXT = {'spots': ('title', 'text'), 'lines': ('label', 'text')}


def english(slug):
    return json.load(open(os.path.join(CATALOG, 'lessons', slug + '.json')))


def strings(d):
    """The translatable part of a lesson, in the same nesting as the lesson file."""
    blocks = []
    for b in d['lesson']:
        out = {'type': b['type']}
        for k in ('title', 'text', 'caption'):
            if b.get(k):
                out[k] = b[k]
        for group, keys in ITEM_TEXT.items():
            if group in b:
                out[group] = [{k: item[k] for k in keys if item.get(k)} for item in b[group]]
        blocks.append(out)
    return {
        'teaser': d['teaser'],
        'lesson': blocks,
        'quiz': [{'question': q['question'], 'options': q['options'], 'explanation': q['explanation']} for q in d['quiz']],
        'facts': [{'text': f['text'], 'explanation': f['explanation']} for f in d['facts']],
    }


def shape(v):
    if isinstance(v, dict):
        return {k: (v[k] if k == 'type' else shape(v[k])) for k in sorted(v)}
    if isinstance(v, list):
        return [shape(x) for x in v]
    return type(v).__name__


def walk(v, path=''):
    if isinstance(v, dict):
        for k, x in v.items():
            if k != 'type':
                yield from walk(x, f'{path}.{k}')
    elif isinstance(v, list):
        for i, x in enumerate(v):
            yield from walk(x, f'{path}[{i}]')
    else:
        yield path, v


def check_lesson(slug, lang):
    path = os.path.join(HERE, lang, 'lessons', slug + '.json')
    if not os.path.exists(path):
        return ['missing file']
    try:
        t = json.load(open(path))
    except Exception as e:
        return [f'invalid JSON: {e}']
    src = strings(english(slug))
    if shape(t) != shape(src):
        return ['structure differs from source/%s.json (same keys, same number of items, same order)' % slug]
    err = []
    same = 0
    pairs = list(zip(walk(src), walk(t)))
    for (p, a), (_, b) in pairs:
        if not b.strip():
            err.append(f'{p}: empty')
        if '—' in b:
            err.append(f'{p}: em dash')
        if a == b and len(a) > 40:
            same += 1
        limit = 300 if re.search(r'(spots|lines)\[\d+\]\.text$', p) else None
        if p == '.teaser':
            limit = 140
        if limit and len(b) > limit:
            err.append(f'{p}: {len(b)} characters (max {limit})')
        if sorted(re.findall(r'\d{3,4}', a)) != sorted(re.findall(r'\d{3,4}', b)) and 'spots' not in p:
            pass  # numbers may legitimately be reformatted (20,000 -> 20 000)
    if same > 2:
        err.append(f'{same} long strings left in English')
    return err


def check_meta(lang):
    path = os.path.join(HERE, lang, 'meta.json')
    if not os.path.exists(path):
        return ['missing meta.json']
    m = json.load(open(path))
    src = json.load(open(os.path.join(HERE, 'source', 'meta.json')))
    err = []
    for part, keys in (('artworks', ('title', 'artist', 'year_label', 'museum')),
                       ('movements', ('name', 'period', 'summary', 'description'))):
        for key in src[part]:
            row = m.get(part, {}).get(key)
            if not row:
                err.append(f'{part}.{key}: missing')
                continue
            for k in keys:
                if not str(row.get(k) or '').strip():
                    err.append(f'{part}.{key}.{k}: empty')
        for key in m.get(part, {}):
            if key not in src[part]:
                err.append(f'{part}.{key}: unknown')
    return err


def merged(slug, lang):
    d = english(slug)
    t = json.load(open(os.path.join(HERE, lang, 'lessons', slug + '.json')))
    d.pop('review_notes', None)
    d['teaser'] = t['teaser']
    for b, tb in zip(d['lesson'], t['lesson']):
        for k in ('title', 'text', 'caption'):
            if k in tb:
                b[k] = tb[k]
        for group, keys in ITEM_TEXT.items():
            for item, ti in zip(b.get(group, []), tb.get(group, [])):
                for k in keys:
                    if k in ti:
                        item[k] = ti[k]
    for q, tq in zip(d['quiz'], t['quiz']):
        q.update(question=tq['question'], options=tq['options'], explanation=tq['explanation'])
    for f, tf in zip(d['facts'], t['facts']):
        f.update(text=tf['text'], explanation=tf['explanation'])
    d['meta'] = json.load(open(os.path.join(HERE, lang, 'meta.json')))['artworks'][slug]
    return typeset(d) if lang == 'fr' else d


def typeset(v):
    """French spacing: non-breaking spaces inside guillemets and before double punctuation."""
    if isinstance(v, dict):
        return {k: (x if k == 'type' else typeset(x)) for k, x in v.items()}
    if isinstance(v, list):
        return [typeset(x) for x in v]
    if isinstance(v, str):
        v = re.sub(r'«[ \u00a0\u202f]?', '«\u00a0', v)
        v = re.sub(r'[ \u00a0\u202f]?»', '\u00a0»', v)
        return re.sub(r'[ \u00a0\u202f]([:;!?])', '\u00a0\\1', v)
    return v


def main():
    cmd = sys.argv[1]
    if cmd == 'extract':
        os.makedirs(os.path.join(HERE, 'source'), exist_ok=True)
        for slug in SLUGS:
            json.dump(strings(english(slug)), open(os.path.join(HERE, 'source', slug + '.json'), 'w'),
                      ensure_ascii=False, indent=1)
        print(len(SLUGS), 'lessons extracted')
    elif cmd == 'check':
        lang = sys.argv[2]
        only = sys.argv[3:]
        bad = 0
        if not only:
            e = check_meta(lang)
            if e:
                bad += 1
                print('meta.json', e[:12])
        for slug in only or SLUGS:
            e = check_lesson(slug, lang)
            if e:
                bad += 1
                print(slug, e[:8])
        print(f'{lang}: {bad} file(s) with problems')
        sys.exit(1 if bad else 0)
    elif cmd == 'merge':
        lang = sys.argv[2]
        out = os.path.join(HERE, 'build', lang)
        os.makedirs(out, exist_ok=True)
        for slug in SLUGS:
            json.dump(merged(slug, lang), open(os.path.join(out, slug + '.json'), 'w'), ensure_ascii=False)
        print(len(SLUGS), 'merged')


if __name__ == '__main__':
    main()
