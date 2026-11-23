"""Google Play screenshots of the Android app, in every language, from the App Store templates (render.py).

Differences with the App Store version:
  - 1398 x 2796 (Google Play accepts at most 2:1): the 1290-wide design centered on white;
  - an Android phone: a punch-hole camera instead of the Dynamic Island;
  - "Art on your Home Screen": a generic Android home screen (no brand icons) with the Artura widget,
    in the language of the screenshot, instead of the iPhone photo.
Also renders the Play Store feature graphic (1024 x 500) per language and the 512 x 512 icon.
Output: out-android/<locale>/<n>_<name>.png, feature.png, and out-android/icon.png.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
os.environ.setdefault("ARTURA_APP", str(HERE.parent / "Artura" / "Resources"))
import render as R  # noqa: E402

OUT = Path(os.environ.get("SHOTS_OUT_ANDROID", HERE / "out-android"))
WIDTH, HEIGHT = 1398, 2796

ISLAND_SMALL = "left: 132px; top: 11px; width: 126px; height: 37px; border-radius: 20px; background: #000"
PUNCH_SMALL = "left: 184px; top: 13px; width: 22px; height: 22px; border-radius: 11px; background: #000"


def android_home(T, lang):
    """A generic Android home screen with the Artura widget (inside the 860 x 1861 phone screen)."""
    S, C = R.load_strings(lang), R.load_content(lang)
    art = C["tournesols"]
    label = S.get("Artwork of the day", "Artwork of the day")
    icons = ["#F3B33D", "#4C8DF6", "#E8604C", "#43A867", "#8E6CE0", "#2BB3C0", "#F07AA5", "#6B7A8F"]
    def row(colors, top):
        return "".join(
            f'<div style="position:absolute; left:{70 + i * 190}px; top:{top}px; width:130px; height:130px; border-radius:65px;'
            f' background:{c}; box-shadow:0 6px 16px rgba(0,0,0,.12)"><div style="position:absolute; left:40px; top:40px;'
            f' width:50px; height:50px; border-radius:14px; background:rgba(255,255,255,.85)"></div></div>'
            for i, c in enumerate(colors))
    img = (HERE / "img" / "tournesols.jpg").as_uri()
    return f'''
      <div style="position:absolute; inset:0; background: radial-gradient(120% 70% at 20% 10%, #CFE0FF 0%, #9DB8F2 40%, #5E79C9 75%, #3E4F94 100%)"></div>
      <div style="position:absolute; left:64px; top:34px; font-size:34px; font-weight:600; color:#fff">9:41</div>
      <div style="position:absolute; right:64px; top:40px; display:flex; gap:14px">
        <div style="width:30px; height:24px; border-radius:4px; background:#fff; opacity:.95"></div>
        <div style="width:44px; height:24px; border-radius:6px; border:3px solid #fff; box-sizing:border-box"></div>
      </div>
      <div style="position:absolute; left:{430 - 18}px; top:30px; width:36px; height:36px; border-radius:18px; background:#000"></div>
      <div style="position:absolute; left:60px; top:170px; font-size:120px; font-weight:500; color:#fff; letter-spacing:-2px">9:41</div>
      <div style="position:absolute; left:52px; top:400px; width:756px; height:420px; border-radius:56px; overflow:hidden;
                  background:#fff; box-shadow:0 24px 60px rgba(20,30,80,.28); display:flex">
        <img src="{img}" style="width:330px; height:420px; object-fit:cover; display:block">
        <div style="flex:1; padding:40px 34px; display:flex; flex-direction:column; gap:12px">
          <div style="font-size:26px; font-weight:700; letter-spacing:.08em; color:#0050C8; text-transform:uppercase">{R.esc(label)}</div>
          <div style="font-size:44px; line-height:1.08; font-weight:700; color:#2D2C2B">{R.esc(art["title"])}</div>
          <div style="font-size:30px; color:#5C5753">{R.esc(art["artist"])} · {R.esc(str(art.get("yearLabel", art["year"])))}</div>
          <div style="font-size:30px; line-height:1.25; color:#2D2C2B; margin-top:auto" data-fith="160">{R.esc(art["teaser"])}</div>
        </div>
      </div>
      {row(icons[:4], 900)}
      {row(icons[4:], 1100)}
      <div style="position:absolute; left:52px; top:1560px; width:756px; height:120px; border-radius:60px; background:rgba(255,255,255,.92)"></div>
      <div style="position:absolute; left:{430 - 90}px; top:1810px; width:180px; height:10px; border-radius:5px; background:rgba(255,255,255,.9)"></div>
    '''


def android_body(name, locale, T, H, weekdays):
    page = R.build(name, locale, T, H, weekdays)
    page = page.replace(ISLAND_SMALL, PUNCH_SMALL)
    if name == "B5-Widget":
        start = page.index('<img src="', page.index("linear-gradient(#C3C3C3, #9C9C9C)"))
        end = page.index("</div>", page.index("left: 291px; top: 24px")) + len("</div>")
        page = page[:start] + android_home(T, R.LOCALES[locale]) + page[end:]
    # Centered on a 2:1 white canvas.
    return page.replace("<style>body{margin:0}", f"<style>body{{margin:0; width:{WIDTH}px; height:{HEIGHT}px; display:flex; justify-content:center; background:#fff}}")


def feature_graphic(H, rtl, locale=""):
    """1024 x 500: the hero headline in a blue bubble, the Mona Lisa and three paintings."""
    links = "".join(f'<link rel="stylesheet" href="{(HERE / c).as_uri()}">' for c in R.FONT_CSS)
    img = lambda f: (HERE / "img" / f).as_uri()
    joiner = "" if locale in ("ja",) else " "
    headline = R.esc(H["hero"].replace("\n", joiner))
    return f'''<!doctype html><html dir="{"rtl" if rtl else "ltr"}"><head><meta charset="utf-8">{links}
<style>body{{margin:0}}</style></head><body>
<div style="width:1024px; height:500px; position:relative; overflow:hidden; background:linear-gradient(135deg,#EAF2FF,#FFFFFF 60%); font-family:{R.FAMILY}">
  <div style="position:absolute; left:640px; top:120px; width:420px; height:420px; border-radius:210px; background:#DCEBFF; filter:blur(40px)"></div>
  <img src="{img('perle.jpg')}" style="position:absolute; left:610px; top:40px; width:110px; height:140px; object-fit:cover; border:8px solid #2D2C2B; transform:rotate(-6deg)">
  <img src="{img('nuit.jpg')}" style="position:absolute; left:740px; top:24px; width:150px; height:118px; object-fit:cover; border:8px solid #2D2C2B">
  <img src="{img('tournesols.jpg')}" style="position:absolute; left:906px; top:44px; width:100px; height:128px; object-fit:cover; border:8px solid #2D2C2B; transform:rotate(5deg)">
  <img src="{img('mascot_hd.png')}" style="position:absolute; left:660px; top:190px; width:330px; height:330px; object-fit:contain; object-position:bottom">
  <div style="position:absolute; left:56px; top:110px; width:520px; padding:36px 40px; box-sizing:border-box; border-radius:56px; background:#0061EF; color:#fff;
              font-size:84px; line-height:1; font-weight:900; letter-spacing:-0.02em" data-fith="280">{headline}</div>
  <div style="position:absolute; left:64px; top:400px; display:flex; align-items:center; gap:16px">
    <img src="{img('icon.png')}" style="width:64px; height:64px; border-radius:16px">
    <div style="font-size:40px; font-weight:800; color:#2D2C2B">Artura</div>
  </div>
</div></body></html>'''


def main(only=None):
    from playwright.sync_api import sync_playwright
    import json
    heads = json.loads((HERE / "headlines.json").read_text("utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = HERE / ".page-android.html"
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH") or None)
        page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT}, device_scale_factor=1)
        # 512 x 512 icon, from the iOS app icon.
        page.set_viewport_size({"width": 512, "height": 512})
        tmp.write_text(f'<html><body style="margin:0"><img src="{(HERE.parent / "Artura/Assets.xcassets/AppIcon.appiconset/icon.png").as_uri()}" style="width:512px;height:512px;display:block"></body></html>')
        page.goto(tmp.as_uri())
        page.screenshot(path=str(OUT / "icon.png"), clip={"x": 0, "y": 0, "width": 512, "height": 512})
        for locale in (only or R.LOCALES):
            T = R.texts_for(locale)
            wd_locale = {"no": "nb"}.get(locale, locale)
            weekdays = page.evaluate("loc => [...Array(7)].map((_, i) => new Intl.DateTimeFormat(loc, {weekday: 'narrow'}).format(new Date(2024, 0, 1 + i)))", wd_locale)
            dest = OUT / locale
            dest.mkdir(parents=True, exist_ok=True)
            page.set_viewport_size({"width": WIDTH, "height": HEIGHT})
            for tpl, fname in R.SCREENS:
                tmp.write_text(android_body(tpl, locale, T, heads[locale], weekdays), "utf-8")
                page.goto(tmp.as_uri(), wait_until="load")
                page.evaluate("document.fonts.ready")
                page.evaluate(R.FIT_JS)
                page.screenshot(path=str(dest / f"{fname}.png"), clip={"x": 0, "y": 0, "width": WIDTH, "height": HEIGHT})
            page.set_viewport_size({"width": 1024, "height": 500})
            tmp.write_text(feature_graphic(heads[locale], locale in R.RTL, locale), "utf-8")
            page.goto(tmp.as_uri(), wait_until="load")
            page.evaluate("document.fonts.ready")
            page.evaluate(R.FIT_JS)
            page.screenshot(path=str(dest / "feature.png"), clip={"x": 0, "y": 0, "width": 1024, "height": 500})
            print("ok", locale)
        browser.close()
    tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    main(sys.argv[1:] or None)
