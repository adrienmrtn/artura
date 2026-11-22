"""Translation of the app itself (interface text + content bundled in the app).

  python3 app.py extract            writes source/content.json (from Artura/Resources/content.json)
                                    and source/ui.json (every L("...") key found in the Swift code)
  python3 app.py check <lang>       checks <lang>/content.json and <lang>/ui.json
  python3 app.py build              writes, for every language that passes the check:
                                      Artura/Resources/<code>.lproj/Localizable.strings (and a copy in ArturaWidget/)
                                      Artura/Resources/content.<code>.json   (onboarding and widget artworks)
                                      Artura/Resources/lessons.<code>.json   (the 100 translated catalog lessons)
Folder names are the codes of ../build.py; <code> is the iOS localization (pt -> pt-BR, sr -> sr-Latn).
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TR = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(TR))
APP = os.path.join(ROOT, 'Artura')
WIDGET = os.path.join(ROOT, 'ArturaWidget')
sys.path.insert(0, TR)
import build  # noqa: E402

LANGS = build.LANGS
IOS_CODE = {'pt': 'pt-BR', 'sr': 'sr-Latn'}
ITEMS = {'spots': ('title', 'text'), 'lines': ('label', 'text'), 'swatches': ('name', 'text')}
PLACEHOLDER = re.compile(r'%(?:\d+\$)?@')


def ios(lang):
    return IOS_CODE.get(lang, lang)


# ---------- content.json ----------

def content_strings(c):
    out = {'movements': {}, 'artworks': {}}
    for m in c['movements']:
        out['movements'][m['id']] = {k: m[k] for k in ('name', 'period', 'summary', 'description')}
    for a in c['artworks']:
        blocks = []
        for b in a['lesson']:
            tb = {'type': b['type']}
            for k in ('title', 'text', 'caption'):
                if b.get(k):
                    tb[k] = b[k]
            for group, keys in ITEMS.items():
                if group in b:
                    tb[group] = [{k: it[k] for k in keys if it.get(k)} for it in b[group]]
            blocks.append(tb)
        out['artworks'][a['id']] = {
            **{k: a[k] for k in ('title', 'artist', 'yearLabel', 'museum', 'teaser')},
            'lesson': blocks,
            'quiz': [{'question': q['question'], 'options': q['options'], 'explanation': q['explanation']} for q in a['quiz']],
            'facts': [{'text': f['text'], 'explanation': f['explanation']} for f in a['facts']],
        }
    return out


def english_content():
    return json.load(open(os.path.join(APP, 'Resources', 'content.json')))


def merged_content(lang):
    c = english_content()
    t = json.load(open(os.path.join(HERE, lang, 'content.json')))
    for m in c['movements']:
        m.update(t['movements'][m['id']])
    for a in c['artworks']:
        ta = t['artworks'][a['id']]
        for k in ('title', 'artist', 'yearLabel', 'museum', 'teaser'):
            a[k] = ta[k]
        for b, tb in zip(a['lesson'], ta['lesson']):
            for k in ('title', 'text', 'caption'):
                if k in tb:
                    b[k] = tb[k]
            for group, keys in ITEMS.items():
                for it, ti in zip(b.get(group, []), tb.get(group, [])):
                    for k in keys:
                        if k in ti:
                            it[k] = ti[k]
        for q, tq in zip(a['quiz'], ta['quiz']):
            q.update(question=tq['question'], options=tq['options'], explanation=tq['explanation'])
        for f, tf in zip(a['facts'], ta['facts']):
            f.update(text=tf['text'], explanation=tf['explanation'])
    return build.typeset(c) if lang == 'fr' else c


# ---------- interface strings ----------

KEY = re.compile(r'\bL\(\s*"((?:[^"\\\n]|\\.)*)"')


def ui_keys():
    keys = {}
    files = glob.glob(os.path.join(APP, '**', '*.swift'), recursive=True) + glob.glob(os.path.join(WIDGET, '*.swift'))
    for f in sorted(files):
        if f.endswith('Localization.swift'):
            continue
        for m in KEY.finditer(open(f).read()):
            raw = m.group(1)
            key = re.sub(r'\\(.)', lambda e: {'n': '\n', 't': '\t'}.get(e.group(1), e.group(1)), raw)
            keys.setdefault(key, os.path.relpath(f, ROOT))
    return keys


def strings_file(pairs):
    def esc(s):
        return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
    return ''.join(f'"{esc(k)}" = "{esc(v)}";\n' for k, v in pairs.items())


# ---------- checks ----------

def walk(v, path=''):
    yield from build.walk(v, path)


def check(lang):
    err = []
    # content
    path = os.path.join(HERE, lang, 'content.json')
    src = json.load(open(os.path.join(HERE, 'source', 'content.json')))
    if not os.path.exists(path):
        err.append('content.json: missing')
    else:
        try:
            t = json.load(open(path))
            if build.shape(t) != build.shape(src):
                err.append('content.json: structure differs from source/content.json')
            else:
                same = 0
                for (p, a), (_, b) in zip(walk(src), walk(t)):
                    if not str(b).strip():
                        err.append(f'content.json{p}: empty')
                    if '\u2014' in b:
                        err.append(f'content.json{p}: em dash')
                    if a == b and len(a) > 40:
                        same += 1
                if same > 2:
                    err.append(f'content.json: {same} long strings left in English')
        except Exception as e:
            err.append(f'content.json: invalid JSON: {e}')
    # ui
    path = os.path.join(HERE, lang, 'ui.json')
    src_ui = json.load(open(os.path.join(HERE, 'source', 'ui.json')))
    if not os.path.exists(path):
        err.append('ui.json: missing')
    else:
        try:
            t = json.load(open(path))
            for k in src_ui:
                v = t.get(k)
                if not isinstance(v, str) or not v.strip():
                    err.append(f'ui.json: missing or empty: {k!r}')
                    continue
                if len(PLACEHOLDER.findall(k)) != len(PLACEHOLDER.findall(v)):
                    err.append(f'ui.json: placeholders differ: {k!r} -> {v!r}')
                formatted = bool(PLACEHOLDER.search(k)) or '%%' in k
                if formatted and re.search(r'%(?!(?:\d+\$)?@)', v.replace('%%', '')):
                    err.append(f'ui.json: stray % (write %% for a percent sign): {k!r} -> {v!r}')
                if '\u2014' in v:
                    err.append(f'ui.json: em dash: {k!r}')
                if k.count('**') != v.count('**'):
                    err.append(f'ui.json: bold markers differ: {k!r}')
            for k in t:
                if k not in src_ui:
                    err.append(f'ui.json: unknown key {k!r}')
        except Exception as e:
            err.append(f'ui.json: invalid JSON: {e}')
    if lang == 'sr':
        for f in ('content.json', 'ui.json'):
            p = os.path.join(HERE, lang, f)
            if os.path.exists(p) and re.search('[\u0400-\u04ff]', open(p, encoding='utf-8').read()):
                err.append(f'{f}: Cyrillic character in a Latin-script language')
    return err


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    os.makedirs(os.path.join(HERE, 'source'), exist_ok=True)
    if cmd == 'extract':
        json.dump(content_strings(english_content()), open(os.path.join(HERE, 'source', 'content.json'), 'w'),
                  ensure_ascii=False, indent=1)
        keys = ui_keys()
        json.dump(keys, open(os.path.join(HERE, 'source', 'ui.json'), 'w'), ensure_ascii=False, indent=1)
        print(f'{len(keys)} interface keys')
    elif cmd == 'check':
        for lang in sys.argv[2:] or LANGS:
            e = check(lang)
            print(f'{lang}: {len(e)} problem(s)')
            for x in e[:60]:
                print('  ', x)
    elif cmd == 'build':
        src_ui = json.load(open(os.path.join(HERE, 'source', 'ui.json')))
        # English: identity table, so that iOS lists English among the app's languages.
        for base in (os.path.join(APP, 'Resources'), WIDGET):
            os.makedirs(os.path.join(base, 'en.lproj'), exist_ok=True)
            open(os.path.join(base, 'en.lproj', 'Localizable.strings'), 'w').write(strings_file({k: k for k in src_ui}))
        done = []
        for lang in LANGS:
            if check(lang):
                print(f'{lang}: skipped (check fails)')
                continue
            code = ios(lang)
            ui = json.load(open(os.path.join(HERE, lang, 'ui.json')))
            if lang == 'fr':
                ui = build.typeset(ui)
            text = strings_file({k: ui[k] for k in src_ui})
            for base in (os.path.join(APP, 'Resources'), WIDGET):
                os.makedirs(os.path.join(base, f'{code}.lproj'), exist_ok=True)
                open(os.path.join(base, f'{code}.lproj', 'Localizable.strings'), 'w').write(text)
            json.dump(merged_content(lang), open(os.path.join(APP, 'Resources', f'content.{code}.json'), 'w'),
                      ensure_ascii=False, separators=(',', ':'))
            lessons = {}
            meta = json.load(open(os.path.join(TR, lang, 'meta.json')))
            for slug in build.SLUGS:
                d = build.merged(slug, lang)
                lessons[slug] = d
            json.dump({'movements': meta['movements'], 'lessons': lessons},
                      open(os.path.join(APP, 'Resources', f'lessons.{code}.json'), 'w'),
                      ensure_ascii=False, separators=(',', ':'))
            done.append(code)
        print('built:', ' '.join(done))
        print('iOS codes:', json.dumps(['en'] + done))
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
