#!/usr/bin/env python3
"""Sends an .aab to a Google Play track (internal by default), as a draft release.

    PLAY_SERVICE_ACCOUNT_JSON='{...}' python3 play_upload.py app-release.aab [track] [status]

Google Play only accepts this once the app's very first version has been uploaded by hand in the Play Console.
"""
import json
import os
import sys

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

PACKAGE = "com.vikstudios.artura"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"

aab, track, status = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "internal"), (sys.argv[3] if len(sys.argv) > 3 else "draft")
creds = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]), scopes=["https://www.googleapis.com/auth/androidpublisher"])
s = AuthorizedSession(creds)


def ok(r):
    if not r.ok:
        sys.exit(f"{r.request.method} {r.url} → {r.status_code}: {r.text[:800]}")
    return r.json()


edit = ok(s.post(f"{API}/edits"))["id"]
with open(aab, "rb") as f:
    bundle = ok(s.post(f"{UPLOAD}/edits/{edit}/bundles", params={"uploadType": "media"}, data=f,
                       headers={"Content-Type": "application/octet-stream"}, timeout=600))
code = bundle["versionCode"]
print(f"Envoyé : version {code}")
ok(s.put(f"{API}/edits/{edit}/tracks/{track}", json={
    "track": track, "releases": [{"versionCodes": [str(code)], "status": status}]}))
ok(s.post(f"{API}/edits/{edit}:commit"))
print(f"Version {code} placée sur la piste « {track} » ({status}).")
