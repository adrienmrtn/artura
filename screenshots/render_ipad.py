"""Render the Artura App Store screenshots for iPad 13" (2064 x 2752), English only.

The iPhone compositions from render.py are scaled to the height of the iPad screenshot and centered
on the same white background, so iPhone and iPad screenshots look the same.
Output: out/en-US/<n>_<name>_ipad.jpg
"""
import json, sys
from playwright.sync_api import sync_playwright

import render
from render import HERE, OUT, SCREENS, FIT_JS, build, texts_for

W, H = 2064, 2752
LOCALE = "en-US"
PLACE_JS = """([w, h]) => {
  const root = document.body.firstElementChild;
  const s = h / root.offsetHeight;
  Object.assign(document.body.style, {margin: '0', width: w + 'px', height: h + 'px', background: '#FFFFFF',
                                      position: 'relative', overflow: 'hidden'});
  Object.assign(root.style, {position: 'absolute', top: '0', left: ((w - root.offsetWidth * s) / 2) + 'px',
                             transformOrigin: 'top left', transform: 'scale(' + s + ')'});
}"""


def main():
    heads = json.loads((HERE / "headlines.json").read_text("utf-8"))
    T = texts_for(LOCALE)
    dest = OUT / LOCALE
    dest.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1290, "height": 2796}, device_scale_factor=1)
        weekdays = page.evaluate("loc => [...Array(7)].map((_, i) => new Intl.DateTimeFormat(loc, {weekday: 'narrow'}).format(new Date(2024, 0, 1 + i)))", LOCALE)
        for tpl, fname in SCREENS:
            tmp = HERE / ".page-ipad.html"
            tmp.write_text(build(tpl, LOCALE, T, heads[LOCALE], weekdays), "utf-8")
            page.set_viewport_size({"width": 1290, "height": 2796})
            page.goto(tmp.as_uri(), wait_until="load")
            page.evaluate("document.fonts.ready")
            page.evaluate(FIT_JS)
            page.set_viewport_size({"width": W, "height": H})
            page.evaluate(PLACE_JS, [W, H])
            page.screenshot(path=str(dest / f"{fname}_ipad.jpg"), type="jpeg", quality=93,
                            clip={"x": 0, "y": 0, "width": W, "height": H})
            print("ok", fname)
        browser.close()


if __name__ == "__main__":
    main()
