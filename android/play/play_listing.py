#!/usr/bin/env python3
"""Store listing of the Android app on Google Play, in every language, from the App Store texts
(fastlane/metadata/<language>/): everything but the screenshots.

- title (30 characters)            ← name.txt
- short description (80)            ← first sentence of promotional_text.txt (subtitle.txt if too long)
- full description (4000)           ← description.txt, without the Apple-only lines (Apple Account, EULA)
- app details                        ← default language en-US, contact e-mail and website

    PLAY_SERVICE_ACCOUNT_JSON='{...}' python3 play_listing.py [--dry-run]
    python3 play_listing.py --check
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from play_subscriptions import API, LANGUAGES, ROOT  # noqa: E402

METADATA = ROOT / "fastlane/metadata"
CONTACT_EMAIL = "support@vikstudios.com"
APPLE_ONLY = re.compile(r"apple|itunes|app store|appstore|iphone|ipad|siri", re.IGNORECASE)


def read(folder, name):
    path = METADATA / folder / name
    return path.read_text().strip() if path.exists() else ""


def first_sentence(text):
    return re.split(r"(?<=[.!?。！？])\s*", text.strip())[0].strip()


def listing(folder):
    title = read(folder, "name.txt")
    promo = read(folder, "promotional_text.txt")
    short = first_sentence(promo)
    if not short or len(short) > 80:
        short = read(folder, "subtitle.txt")
    lines = [l for l in read(folder, "description.txt").splitlines() if not APPLE_ONLY.search(l)]
    full = re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()
    return {"language": LANGUAGES[folder], "title": title, "shortDescription": short, "fullDescription": full}


def all_listings():
    out, problems = [], []
    for folder in sorted(p.name for p in METADATA.iterdir() if p.is_dir()):
        if folder not in LANGUAGES:
            problems.append(f"langue sans code Google Play : {folder}")
            continue
        l = listing(folder)
        for key, limit in (("title", 30), ("shortDescription", 80), ("fullDescription", 4000)):
            if not l[key]:
                problems.append(f"{folder}: {key} vide")
            elif len(l[key]) > limit:
                problems.append(f"{folder}: {key} trop long ({len(l[key])} > {limit})")
        out.append(l)
    return out, problems


def run(dry):
    listings, problems = all_listings()
    if problems:
        sys.exit("\n".join(problems))
    for l in listings:
        print(f"  {l['language']:7} {l['title']}  |  {l['shortDescription']}")
    if dry:
        print(f"\n[simulation] {len(listings)} fiches seraient envoyées. Rien n'a été écrit.")
        return

    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]), scopes=["https://www.googleapis.com/auth/androidpublisher"])
    s = AuthorizedSession(creds)

    def ok(r):
        if not r.ok:
            raise RuntimeError(f"{r.request.method} {r.url} → {r.status_code}: {r.text[:800]}")
        return r.json() if r.text else {}

    edit = ok(s.post(f"{API}/edits"))["id"]
    ok(s.patch(f"{API}/edits/{edit}/details", json={"defaultLanguage": "en-US", "contactEmail": CONTACT_EMAIL}))
    for l in listings:
        ok(s.put(f"{API}/edits/{edit}/listings/{l['language']}", json=l))
    r = s.post(f"{API}/edits/{edit}:commit")
    if not r.ok and "changesNotSentForReview" in r.text:
        r = s.post(f"{API}/edits/{edit}:commit", params={"changesNotSentForReview": "true"})
    ok(r)
    print(f"\n{len(listings)} fiches enregistrées sur Google Play.")


if __name__ == "__main__":
    if "--check" in sys.argv:
        _, problems = all_listings()
        print("\n".join(problems) or "Fichiers OK")
        sys.exit(1 if problems else 0)
    run("--dry-run" in sys.argv)
