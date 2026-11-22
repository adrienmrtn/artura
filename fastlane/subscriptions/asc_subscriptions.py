#!/usr/bin/env python3
"""Abonnements Artura dans App Store Connect : textes localisés + prix annuels.

  python3 asc_subscriptions.py --check            contrôle hors ligne des fichiers
  python3 asc_subscriptions.py --dry-run          montre ce qui serait fait (lecture seule)
  python3 asc_subscriptions.py                    applique

Variables d'environnement : ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contenu du .p8).
Ce script ne touche JAMAIS au prix de l'abonnement mensuel.
"""
import argparse
import base64
import json
import os
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).parent
META = HERE.parent / "metadata"
API = "https://api.appstoreconnect.apple.com"
LIMITS = {"name": 30, "description": 55, "group": 64, "app": 30}


def load():
    loc = json.loads((HERE / "localizations.json").read_text(encoding="utf-8"))
    pricing = json.loads((HERE / "pricing.json").read_text(encoding="utf-8"))
    return loc, pricing


def app_name(locale):
    f = META / locale / "name.txt"
    return f.read_text(encoding="utf-8") if f.exists() else None


def check():
    loc, pricing = load()
    errors = []
    for l, v in loc.items():
        for pid, s in v["subscriptions"].items():
            if len(s["name"]) > LIMITS["name"]:
                errors.append(f"{l}/{pid}: nom trop long ({len(s['name'])})")
            if len(s["description"]) > LIMITS["description"]:
                errors.append(f"{l}/{pid}: description trop longue ({len(s['description'])})")
        if len(v["group"]["name"]) > LIMITS["group"]:
            errors.append(f"{l}: nom du groupe trop long")
        if app_name(l) is None:
            errors.append(f"{l}: pas de fastlane/metadata/{l}/name.txt")
    seen = {}
    for t in pricing["tiers"]:
        for c in t["territories"]:
            if c in seen:
                errors.append(f"{c} est dans deux tranches")
            seen[c] = t["yearly"]
    print(f"{len(loc)} langues, {len(seen)} pays en tranches")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print("OK")


# ---------------------------------------------------------------- API
class Api:
    def __init__(self):
        import jwt  # PyJWT
        import requests
        self.jwt, self.requests = jwt, requests
        self.token, self.exp = None, 0

    def _token(self):
        if time.time() > self.exp - 60:
            now = int(time.time())
            self.exp = now + 1200
            self.token = self.jwt.encode(
                {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": self.exp,
                 "aud": "appstoreconnect-v1"},
                os.environ["ASC_KEY_P8"], algorithm="ES256",
                headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
        return self.token

    def call(self, method, path, body=None, params=None):
        url = path if path.startswith("http") else API + path
        for attempt in range(6):
            r = self.requests.request(
                method, url, params=params, json=body, timeout=60,
                headers={"Authorization": f"Bearer {self._token()}"})
            if r.status_code in (429, 500, 502, 503, 504):
                time.sleep(2 ** attempt)
                continue
            if r.status_code >= 400:
                raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:600]}")
            return r.json() if r.text else {}
        raise RuntimeError(f"{method} {path}: trop d'échecs")

    def pages(self, path, params=None):
        """Toutes les pages d'une liste : (data, included)."""
        data, inc = [], []
        params = dict(params or {})
        params.setdefault("limit", 200)
        url = path
        while url:
            j = self.call("GET", url, params=params)
            data += j.get("data", [])
            inc += j.get("included", [])
            url = j.get("links", {}).get("next")
            params = None
        return data, inc


def rel_id(obj, name):
    d = (obj.get("relationships", {}).get(name, {}) or {}).get("data")
    return d["id"] if d else None


def pp_territory(pp):
    t = rel_id(pp, "territory")
    if t:
        return t
    raw = pp["id"] + "=" * (-len(pp["id"]) % 4)
    return json.loads(base64.urlsafe_b64decode(raw))["t"]


def find_products(api, pricing):
    apps, _ = api.pages("/v1/apps", {"filter[bundleId]": pricing["bundle_id"]})
    if not apps:
        sys.exit("App introuvable : " + pricing["bundle_id"])
    app_id = apps[0]["id"]
    groups, _ = api.pages(f"/v1/apps/{app_id}/subscriptionGroups")
    if not groups:
        sys.exit("Aucun groupe d'abonnements")
    subs = []
    for g in groups:
        s, _ = api.pages(f"/v1/subscriptionGroups/{g['id']}/subscriptions")
        subs += [(g["id"], x) for x in s]
    print("Abonnements trouvés :")
    for g, s in subs:
        a = s["attributes"]
        print(f"  {a.get('productId')}  «{a.get('name')}»  {a.get('subscriptionPeriod')}  {a.get('state')}")
    found = {}
    for key, pid in pricing["products"].items():
        for g, s in subs:
            if s["attributes"].get("productId") == pid:
                found[key] = (g, s)
    if len(found) < 3:  # repli : par nom et durée
        for g, s in subs:
            a = s["attributes"]
            name = (a.get("name") or "").lower()
            per = a.get("subscriptionPeriod")
            key = "gift" if "gift" in name or "cadeau" in name else (
                "monthly" if per == "ONE_MONTH" else "yearly" if per == "ONE_YEAR" else None)
            if key and key not in found:
                found[key] = (g, s)
                print(f"  (repli par nom) {a.get('productId')} -> {key}")
    missing = [k for k in pricing["products"] if k not in found]
    if missing:
        sys.exit("Abonnements introuvables : " + ", ".join(missing))
    return found


# ---------------------------------------------------------------- textes
def sync_localizations(api, found, loc, dry):
    errors = []
    names = {"yearly": "Artura_yearly", "monthly": "Artura_monthly", "gift": "Artura_yearly_gift"}
    for key, (gid, sub) in found.items():
        sid = sub["id"]
        existing, _ = api.pages(f"/v1/subscriptions/{sid}/subscriptionLocalizations")
        by_loc = {e["attributes"]["locale"]: e for e in existing}
        for locale, v in loc.items():
            want = v["subscriptions"][names[key]]
            cur = by_loc.get(locale)
            try:
                if cur is None:
                    print(f"+ {key} {locale}: {want['name']}")
                    if not dry:
                        api.call("POST", "/v1/subscriptionLocalizations", {"data": {
                            "type": "subscriptionLocalizations",
                            "attributes": {"locale": locale, **want},
                            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
                elif (cur["attributes"].get("name"), cur["attributes"].get("description")) != (want["name"], want["description"]):
                    print(f"~ {key} {locale}: {cur['attributes'].get('name')} -> {want['name']}")
                    if not dry:
                        api.call("PATCH", f"/v1/subscriptionLocalizations/{cur['id']}", {"data": {
                            "type": "subscriptionLocalizations", "id": cur["id"], "attributes": want}})
            except Exception as e:  # ex. texte déjà approuvé et verrouillé
                errors.append(f"texte {key} {locale}: {e}")
    # groupe : nom affiché + nom d'app
    gid = next(iter(found.values()))[0]
    existing, _ = api.pages(f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations")
    by_loc = {e["attributes"]["locale"]: e for e in existing}
    for locale, v in loc.items():
        want = {"name": v["group"]["name"], "customAppName": app_name(locale)}
        cur = by_loc.get(locale)
        try:
            if cur is None:
                print(f"+ groupe {locale}: {want['name']}")
                if not dry:
                    api.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {
                        "type": "subscriptionGroupLocalizations",
                        "attributes": {"locale": locale, **want},
                        "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            elif (cur["attributes"].get("name"), cur["attributes"].get("customAppName")) != (want["name"], want["customAppName"]):
                print(f"~ groupe {locale}: {cur['attributes'].get('name')} -> {want['name']}")
                if not dry:
                    api.call("PATCH", f"/v1/subscriptionGroupLocalizations/{cur['id']}", {"data": {
                        "type": "subscriptionGroupLocalizations", "id": cur["id"], "attributes": want}})
        except Exception as e:
            errors.append(f"groupe {locale}: {e}")
    return errors


# ---------------------------------------------------------------- prix
def tier_of(territory, pricing):
    for t in pricing["tiers"]:
        if territory in t["territories"]:
            return t
    return pricing["default"]


def plan_prices(api, sub, kind, pricing, territories):
    """Pour un abonnement : {territoire: (pricePointId, prix)} selon les tranches."""
    sid = sub["id"]
    exact = set(pricing["exact_price_currencies"])
    base = {}
    result = {}
    # points de prix américains par valeur de tranche
    us, _ = api.pages(f"/v1/subscriptions/{sid}/pricePoints", {"filter[territory]": "USA"})
    us_by_price = {p["attributes"]["customerPrice"]: p for p in us}
    equal = {}
    for tier_price in sorted({tier_of(t, pricing)[kind] for t in territories}):
        p = us_by_price.get(tier_price)
        if p is None:
            raise RuntimeError(f"Pas de price point US à {tier_price} pour {sub['attributes'].get('productId')}")
        base[tier_price] = p
        data, _ = api.pages(f"/v1/subscriptionPricePoints/{p['id']}/equalizations", {"include": "territory"})
        equal[tier_price] = {pp_territory(x): x for x in data}
    for terr, currency in territories.items():
        price = tier_of(terr, pricing)[kind]
        if currency in exact:
            pts, _ = api.pages(f"/v1/subscriptions/{sid}/pricePoints", {"filter[territory]": terr})
            hit = next((x for x in pts if x["attributes"]["customerPrice"] == price), None)
            if hit is None:
                print(f"  ! {terr}: pas de point à {price} {currency}, ignoré")
                continue
        elif terr == "USA":
            hit = base[price]
        else:
            hit = equal[price].get(terr)
            if hit is None:
                print(f"  ! {terr}: pas d'équivalent à {price} $, ignoré")
                continue
        result[terr] = (hit["id"], hit["attributes"]["customerPrice"])
    return result


def current_prices(api, sid):
    data, inc = api.pages(f"/v1/subscriptions/{sid}/prices", {"include": "subscriptionPricePoint"})
    pts = {i["id"]: i["attributes"]["customerPrice"] for i in inc if i["type"] == "subscriptionPricePoints"}
    today = time.strftime("%Y-%m-%d")
    cur = {}
    for d in data:
        start = d["attributes"].get("startDate")
        if start and start > today:
            continue
        t = rel_id(d, "territory")
        if t is None:
            continue
        key = start or ""
        pp = rel_id(d, "subscriptionPricePoint")
        if t not in cur or key >= cur[t][0]:
            cur[t] = (key, pts.get(pp))
    return {t: v[1] for t, v in cur.items() if v[1] is not None}


def sync_prices(api, found, pricing, dry):
    errors = []
    terrs, _ = api.pages("/v1/territories")
    territories = {t["id"]: t["attributes"].get("currency") for t in terrs}
    for kind in ("yearly", "gift"):
        _, sub = found[kind]
        sid = sub["id"]
        print(f"\n== Prix {kind} ({sub['attributes'].get('productId')}) ==")
        plan = plan_prices(api, sub, kind, pricing, territories)  # tout est calculé avant d'écrire
        cur = current_prices(api, sid)
        n = 0
        for terr, (ppid, price) in sorted(plan.items()):
            old = cur.get(terr)
            if old is not None and float(old) == float(price):
                continue
            attrs = {}
            if old is not None and float(price) > float(old):
                attrs["preserveCurrentPrice"] = True  # les abonnés actuels gardent leur prix
            print(f"  {terr} ({territories[terr]}): {old} -> {price}")
            n += 1
            if dry:
                continue
            try:
                api.call("POST", "/v1/subscriptionPrices", {"data": {
                    "type": "subscriptionPrices", "attributes": attrs,
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": ppid}},
                        "territory": {"data": {"type": "territories", "id": terr}}}}})
            except Exception as e:
                errors.append(f"prix {kind} {terr}: {e}")
        print(f"  {n} pays à modifier, {len(plan) - n} déjà bons")
    return errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-prices", action="store_true")
    ap.add_argument("--skip-texts", action="store_true")
    a = ap.parse_args()
    if a.check:
        return check()
    check()
    loc, pricing = load()
    api = Api()
    found = find_products(api, pricing)
    errors = []
    if not a.skip_texts:
        errors += sync_localizations(api, found, loc, a.dry_run)
    if not a.skip_prices:
        errors += sync_prices(api, found, pricing, a.dry_run)
    if errors:
        print("\nÉCHECS :")
        print("\n".join(errors))
        sys.exit(1)
    print("\nTerminé" + (" (simulation, rien n'a été écrit)" if a.dry_run else ""))


if __name__ == "__main__":
    main()
