"""Render the Artura App Store screenshots (version B) in every App Store locale.

Texts come from two places:
  - headlines.json: the marketing headlines, one set per App Store locale;
  - the app itself: Artura/Resources/<lang>.lproj/Localizable.strings and content[.<lang>].json,
    so every label and the Starry Night lesson inside the phone use Artura's real translations.
Output: out/<locale>/<n>_<name>.jpg at 1290 x 2796 (iPhone 6.9").
"""
import html, json, os, re, sys
from pathlib import Path
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
APP = Path(os.environ.get("ARTURA_APP", HERE.parent / "artura" / "Artura" / "Resources"))
OUT = Path(os.environ.get("SHOTS_OUT", HERE / "out"))

LOCALES = {  # App Store locale -> app language (None: app not translated, English inside the phone)
    "en-US": "en", "en-AU": "en", "en-GB": "en", "fr-FR": "fr", "de-DE": "de", "es-ES": "es",
    "es-MX": "es", "it": "it", "pt-BR": "pt-BR", "pt-PT": "pt-PT", "nl-NL": "nl", "da": "da",
    "sv": "sv", "no": "nb", "fi": "fi", "pl": "pl", "cs": "cs", "sk": "sk", "sl-SI": "sl",
    "hr": "hr", "hu": "hu", "ro": "ro", "tr": "tr", "el": "el", "ru": "ru", "ar-SA": "ar",
    "he": "he", "ja": "ja", "ko": None,
}
RTL = {"ar-SA", "he"}
SCREENS = [("B1-Hero", "1_learn_art"), ("B2-Story", "2_story"), ("B3-Details", "3_closer_look"),
           ("B4-Games", "4_games"), ("B5-Widget", "5_widget"), ("B6-Collection", "6_collection")]
BLOBS = {
    "6dffd91fa04c72c753bc76fbf9331eaa": "mascot_hd.png", "65381b169bbf47bb53d4beadb65c7f2a": "icon.png",
    "11ca697ebfb533af19936b40fe40ca5d": "nuit.jpg", "5dfa59590244cc128cd2b6cad6be853e": "perle.jpg",
    "5dbd7456427f45ef0e502abc7fb5852b": "joconde.jpg", "ec0aae2291f32ad6c378625e68fa9d7e": "vague.jpg",
    "c59e5cbc867300a806c0c47d079bb2ad": "baiser.jpg", "f08acb76270b0b9b88a137659ca69472": "nympheas.jpg",
    "f3435ccb4dfb9c9148f34986bada5f0e": "impression.jpg", "be0f298b4c97dd0ee55fd35091985f55": "tournesols.jpg",
    "3a4289d4714ebff6fa7387634aba608b": "menines.jpg", "3f1784b12ce8cd77fb8a2084c5a351a4": "grandejatte.jpg",
    "1f6463420a9a1af7bebca4bf1ef16b7e": "glaneuses.jpg", "2988a994166917e3fbbb058d016a0a51": "raboteurs.jpg",
    "f3016f61e3838326c9bf09fa87bb111a": "ill_zoom.jpg", "0b78ad209ab8c31605588e67d52f2138": "ill_chrono.jpg",
    "a57a492e7702afa3e1b44be4d8267085": "ill_palette.jpg", "9f91a9338245fac29bd8c4480221af1d": "ill_vraifaux.jpg",
    "714928778d15d26078f4ed83e483faa2": "widget_home.jpg", "9e8423dc40d0cd1bf9b48964b330e6f9": "ill_musee.jpg",
}
FONT_CSS = [f"node_modules/@fontsource/figtree/{w}.css" for w in (400, 500, 600, 700, 800, 900)] + [
    f"node_modules/@fontsource/{p}/{w}.css"
    for p in ("noto-sans", "noto-sans-arabic", "noto-sans-hebrew", "noto-sans-jp", "noto-sans-kr")
    for w in (400, 600, 700, 800, 900) if (HERE / f"node_modules/@fontsource/{p}/{w}.css").exists()]
FAMILY = "'Figtree', 'Noto Sans', 'Noto Sans Arabic', 'Noto Sans Hebrew', 'Noto Sans JP', 'Noto Sans KR', sans-serif"


def load_strings(lang):
    path = APP / f"{lang or 'en'}.lproj" / "Localizable.strings"
    pairs = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', path.read_text("utf-8"), re.M)
    unesc = lambda s: s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
    return {unesc(k): unesc(v) for k, v in pairs}


def load_content(lang):
    name = "content.json" if lang in (None, "en") else f"content.{lang}.json"
    data = json.loads((APP / name).read_text("utf-8"))
    return {a["id"]: a for a in data["artworks"]}


def fill(fmt, *values):
    """Fill %@ and %1$@ style placeholders."""
    vals = list(map(str, values))
    fmt = re.sub(r"%(\d)\$@", lambda m: vals[int(m.group(1)) - 1], fmt)
    it = iter(vals)
    return re.sub(r"%@", lambda m: next(it), fmt)


def esc(s):
    return html.escape(s, quote=False).replace("\n", "<br>")


def texts_for(locale):
    lang = LOCALES[locale]
    S, C = load_strings(lang), load_content(lang)
    L = lambda k: S.get(k, k)
    nuit, joconde = C["nuit"], C["joconde"]
    blocks = nuit["lesson"]
    first_text = next(b["text"] for b in blocks if b["type"] == "text")
    fact = next(b["text"] for b in blocks if b["type"] == "fact")
    key = next(b["text"] for b in blocks if b["type"] == "key")
    moon = next(b for b in blocks if b["type"] == "tour")["spots"][1]
    return {
        "lesson_title": nuit["title"],
        "lesson_meta": f'{nuit["artist"]} · {nuit.get("yearLabel", nuit["year"])} · {nuit["museum"]}',
        "lesson_text": first_text, "fact": fact, "key": key,
        "did_you_know": L("Did you know?"), "key_takeaway": L("Key takeaway"), "continue": L("Continue"),
        "moon_title": moon["title"], "moon_text": moon["text"], "next": L("Next"),
        "games": L("Games"), "streak": fill(L("%@-day streak"), 12), "keep": L("Play today to keep it"),
        "resume": L("Resume practice"), "progress": fill(L("%@ of %@ today · %@ to go"), 12, 30, 18),
        "pick": L("Or pick a game"), "daily": L("Daily challenge"),
        "zoom": L("Mystery Zoom"), "zoom_sub": L("Guess the artwork from a detail · 1 min"),
        "chrono": L("Timeline"), "chrono_sub": L("Put 4 artworks in date order · 2 min"),
        "palette": L("Palette"), "palette_sub": L("Match the painting's colors · 1 min"),
        "mona": joconde["title"],
        "hello": L("Hi, I'm Artura. Every day, I'll show you one masterpiece and the story behind it."),
    }


def rep(src, old, new, count=1):
    if old not in src:
        sys.exit(f"template text not found: {old[:80]!r}")
    return src.replace(old, new, count)


def build(name, locale, T, H, weekdays):
    src = (HERE / "templates" / f"{name}.dc.html").read_text("utf-8")
    body = src.split("</helmet>", 1)[1].split("</x-dc>", 1)[0]
    for blob, f in BLOBS.items():
        body = body.replace(f"/_blob/{blob}", (HERE / "img" / f).as_uri())
    body = body.replace("font-family: 'Figtree', system-ui, sans-serif", f"font-family: {FAMILY}")
    e = {k: esc(v) for k, v in T.items()}
    if name == "B1-Hero":
        body = rep(body, ">Learn<br>Art.</h1>", f' data-fit="1">{esc(H["hero"])}</h1>')
    elif name == "B2-Story":
        body = rep(body, ">Every work<br>has a story.</h1>", f' data-fit="1">{esc(H["story"])}</h1>')
        body = rep(body, ">The Starry Night<", f'>{e["lesson_title"]}<')
        body = rep(body, ">Vincent van Gogh · 1889 · MoMA, New York<", f'>{e["lesson_meta"]}<')
        body = rep(body, "height: 200px; border-radius: 16px", "height: 170px; border-radius: 16px")
        body = rep(body, ">June 1889. Van Gogh is 36. A month earlier, he checked himself into the asylum of Saint-Rémy-de-Provence.<", f'>{e["lesson_text"]}<')
        body = rep(body, ">Did you know?<", f'>{e["did_you_know"]}<')
        body = rep(body, ">Van Gogh only started painting at 27.<", f'>{e["fact"]}<')
        body = re.sub(r'\s*<p style="[^"]*">He painted this sky by day, from memory and imagination\.</p>', "", body)
        body = rep(body, ">Continue<", f'>{e["continue"]}<')
        body = rep(body, ">Key takeaway<", f'>{e["key_takeaway"]}<')
        body = rep(body, 'font-size: 42px; line-height: 1.15; font-weight: 700; color: #2D2C2B">It is not a view. It is a vision.<',
                   f'font-size: 38px; line-height: 1.18; font-weight: 700; color: #2D2C2B" data-fith="300">{e["key"]}<')
    elif name == "B3-Details":
        body = rep(body, ">Take a<br>closer look.</h1>", f' data-fit="1">{esc(H["closer"])}</h1>')
        body = rep(body, "top: 560px; width: 366px", "bottom: 24px; width: 366px")
        body = rep(body, ">The moon<", f'>{e["moon_title"]}<', 2)
        body = rep(body, ">An orange crescent in a yellow halo. It almost looks like a sun.<", f'>{e["moon_text"]}<')
        body = rep(body, ">Next detail<", f'>{e["next"]}<')
    elif name == "B4-Games":
        body = rep(body, ">Play.<br>Remember.</h1>", f' data-fit="1">{esc(H["games"])}</h1>')
        for k, en in [("games", "Games"), ("streak", "12-day streak"), ("keep", "Play today to keep it"),
                      ("resume", "Resume practice"), ("progress", "12 of 30 today · 18 to go"),
                      ("pick", "Or pick a game"), ("daily", "Daily challenge"), ("zoom", "Mystery Zoom"),
                      ("zoom_sub", "Guess the artwork from a detail · 1 min"), ("chrono", "Timeline"),
                      ("chrono_sub", "Put 4 artworks in date order · 2 min"), ("palette", "Palette"),
                      ("palette_sub", "Match the painting's colors · 1 min")]:
            body = rep(body, f">{en}<", f">{e[k]}<")
        body = rep(body, "</span>Mona Lisa\n", f"</span>{e['mona']}\n")
        days = iter(weekdays)
        body = re.sub(r'(<span style="font-size: 12px;[^"]*">)[MTWFS](</span>)',
                      lambda m: m.group(1) + esc(next(days)) + m.group(2), body)
    elif name == "B5-Widget":
        body = rep(body, ">Art on your<br>Home Screen.</h1>", f' data-fit="1">{esc(H["widget"])}</h1>')
    elif name == "B6-Collection":
        body = rep(body, ">From Leonardo<br>to Klimt</h1>", f' data-fit="1">{esc(H["collection"])}</h1>')
        body = rep(body, "left: 100px; top: 2120px; width: 760px;", "left: 100px; bottom: 406px; width: 760px;")
        body = rep(body, ">Hi, I'm Artura. Every day, I'll show you one masterpiece and its story.<",
                   f' data-fith="300">{e["hello"]}<')
    lang_attr = locale.split("-")[0]
    links = "".join(f'<link rel="stylesheet" href="{(HERE / c).as_uri()}">' for c in FONT_CSS)
    return (f'<!doctype html><html lang="{lang_attr}" dir="{"rtl" if locale in RTL else "ltr"}"><head>'
            f'<meta charset="utf-8">{links}<style>body{{margin:0}} h1[data-fit]{{white-space:nowrap}}</style>'
            f"</head><body>{body}</body></html>")


FIT_JS = """() => {
  for (const el of document.querySelectorAll('h1[data-fit]')) {
    const box = el.parentElement.closest('[style*="border-radius: 110px"]');
    const max = box ? box.clientWidth - 110 : 1290 - 110;
    const w0 = el.style.width;
    el.style.width = 'max-content';
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (el.getBoundingClientRect().width > max && size > 60) { size -= 2; el.style.fontSize = size + 'px'; }
    el.style.width = w0;
  }
  for (const el of document.querySelectorAll('[data-fith]')) {
    const max = +el.dataset.fith;
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (el.getBoundingClientRect().height > max && size > 20) { size -= 1; el.style.fontSize = size + 'px'; }
  }
}"""


def main(only=None):
    heads = json.loads((HERE / "headlines.json").read_text("utf-8"))
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1290, "height": 2796}, device_scale_factor=1)
        for locale in (only or LOCALES):
            T = texts_for(locale)
            wd_locale = {"no": "nb"}.get(locale, locale)
            weekdays = page.evaluate("loc => [...Array(7)].map((_, i) => new Intl.DateTimeFormat(loc, {weekday: 'narrow'}).format(new Date(2024, 0, 1 + i)))", wd_locale)
            dest = OUT / locale
            dest.mkdir(parents=True, exist_ok=True)
            for tpl, fname in SCREENS:
                tmp = HERE / ".page.html"
                tmp.write_text(build(tpl, locale, T, heads[locale], weekdays), "utf-8")
                page.goto(tmp.as_uri(), wait_until="load")
                page.evaluate("document.fonts.ready")
                page.evaluate(FIT_JS)
                page.screenshot(path=str(dest / f"{fname}.jpg"), type="jpeg", quality=93, clip={"x": 0, "y": 0, "width": 1290, "height": 2796})
            print("ok", locale)
        browser.close()


if __name__ == "__main__":
    main(sys.argv[1:] or None)
