import json, sys, glob, os, urllib.request, re
# Needs a deployed import function (see STATUS.md) and its token in the IMPORT_TOKEN environment variable.
TOKEN = os.environ['IMPORT_TOKEN']
src = open('/home/user/artura/Artura/Data/RemoteCatalog.swift').read()
ANON = re.search(r'key = "([^"]+)"', src).group(1)
URL = 'https://dsbhaddvzpswkjzqskhv.supabase.co/functions/v1/import-translations'
def post(body):
    req = urllib.request.Request(URL, data=json.dumps(body, ensure_ascii=False).encode(), method='POST',
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + ANON, 'apikey': ANON, 'x-import-token': TOKEN})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)
test = len(sys.argv) > 1 and sys.argv[1] == 'test'
files = sorted(glob.glob('/home/user/artura/Artura/Resources/lessons.*.json'))
for f in files:
    code = f.split('lessons.')[1][:-5]
    d = json.load(open(f))
    slugs = sorted(d['lessons'])
    if test:
        print(post({'lang': code, 'lessons': {slugs[0]: d['lessons'][slugs[0]]}})); break
    r = post({'lang': code, 'movements': d['movements']}); assert r['ok'], r
    n = 0
    for i in range(0, len(slugs), 25):
        part = {s: d['lessons'][s] for s in slugs[i:i+25]}
        r = post({'lang': code, 'lessons': part}); assert r['ok'], r
        n += len(r['out'])
    print(code, 'lessons', n, flush=True)
