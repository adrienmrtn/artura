#!/usr/bin/env python3
"""Sends the Google Play images of every language (rendered by screenshots/render_android.py):
phone screenshots (replacing the existing ones), feature graphic and icon.

    PLAY_SERVICE_ACCOUNT_JSON='{...}' python3 play_images.py screenshots/out-android
"""
import json
import os
import sys
from pathlib import Path

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

sys.path.insert(0, str(Path(__file__).parent))
from play_subscriptions import API, LANGUAGES, PACKAGE, request_with_retry  # noqa: E402

UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "screenshots/out-android")

creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]), scopes=["https://www.googleapis.com/auth/androidpublisher"])
s = AuthorizedSession(creds)


def ok(r):
    if not r.ok:
        sys.exit(f"{r.request.method} {r.url} → {r.status_code}: {r.text[:800]}")
    return r.json() if r.text else {}


def upload(edit, lang, kind, path):
    with open(path, "rb") as f:
        ok(request_with_retry(s, "POST", f"{UPLOAD}/edits/{edit}/listings/{lang}/{kind}",
                              params={"uploadType": "media"}, data=f.read(), headers={"Content-Type": "image/png"}))


edit = ok(request_with_retry(s, "POST", f"{API}/edits"))["id"]
icon = OUT / "icon.png"
for folder in sorted(p.name for p in OUT.iterdir() if p.is_dir()):
    lang = LANGUAGES.get(folder)
    if not lang:
        print(f"  ignoré : {folder}")
        continue
    shots = sorted((OUT / folder).glob("[0-9]_*.png"))
    for kind in ("phoneScreenshots", "featureGraphic", "icon"):
        ok(request_with_retry(s, "DELETE", f"{API}/edits/{edit}/listings/{lang}/{kind}"))
    for shot in shots:
        upload(edit, lang, "phoneScreenshots", shot)
    if (OUT / folder / "feature.png").exists():
        upload(edit, lang, "featureGraphic", OUT / folder / "feature.png")
    if icon.exists():
        upload(edit, lang, "icon", icon)
    print(f"  {lang:7} {len(shots)} captures, image de présentation, icône")
r = request_with_retry(s, "POST", f"{API}/edits/{edit}:commit")
if not r.ok and "changesNotSentForReview" in r.text:
    r = request_with_retry(s, "POST", f"{API}/edits/{edit}:commit", params={"changesNotSentForReview": "true"})
ok(r)
print("Images enregistrées sur Google Play.")
