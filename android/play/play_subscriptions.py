#!/usr/bin/env python3
"""Creates (or updates) the 3 Artura Pro subscriptions on Google Play, like asc_subscriptions.py for iOS.

- artura_yearly       base plan "yearly"  (P1Y), free trial offer "trial" of 3 days
- artura_monthly      base plan "monthly" (P1M), free trial offer "trial" of 3 days
- artura_yearly_gift  base plan "yearly"  (P1Y), free trial offer "trial" of 7 days

Prices: the same tiers as the App Store (fastlane/subscriptions/pricing.json): the tier price in US dollars
is converted by Google into every currency; in the countries that pay in USD or EUR the tier price is used
as is (29.99 stays 29.99). The monthly plan costs MONTHLY_USD everywhere (converted).
Names and descriptions: fastlane/subscriptions/localizations.json (the App Store texts), in every language.

Usage (GitHub Actions, "Google Play subscriptions" workflow):
    PLAY_SERVICE_ACCOUNT_JSON='{...}' python3 play_subscriptions.py [--dry-run]
    python3 play_subscriptions.py --check     # checks the files only, no network
"""
import json
import os
import sys
from decimal import Decimal
from pathlib import Path

PACKAGE = "com.vikstudios.artura"
ROOT = Path(__file__).resolve().parents[2]
PRICING = ROOT / "fastlane/subscriptions/pricing.json"
TEXTS = ROOT / "fastlane/subscriptions/localizations.json"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
REGIONS_VERSION = "2022/02"
MONTHLY_USD = "6.99"

# Google Play product id → (iOS product id, pricing kind, base plan id, billing period, free trial)
PRODUCTS = {
    "artura_yearly": ("Artura_yearly", "yearly", "yearly", "P1Y", "P3D"),
    "artura_monthly": ("Artura_monthly", "monthly", "monthly", "P1M", "P3D"),
    "artura_yearly_gift": ("Artura_yearly_gift", "gift", "yearly", "P1Y", "P7D"),
}

# App Store language folders (localizations.json) → Google Play language codes.
LANGUAGES = {
    "en-US": "en-US", "en-AU": "en-AU", "en-GB": "en-GB", "es-MX": "es-419", "ko": "ko-KR", "sl-SI": "sl",
    "ar-SA": "ar", "bg": "bg", "cs": "cs-CZ", "da": "da-DK", "de-DE": "de-DE", "el": "el-GR",
    "es-ES": "es-ES", "et": "et", "fi": "fi-FI", "fr-FR": "fr-FR", "he": "iw-IL", "hr": "hr", "hu": "hu-HU",
    "it": "it-IT", "ja": "ja-JP", "lt": "lt", "lv": "lv", "nl-NL": "nl-NL", "no": "no-NO", "pl": "pl-PL",
    "pt-BR": "pt-BR", "pt-PT": "pt-PT", "ro": "ro", "ru": "ru-RU", "sk": "sk", "sl": "sl", "sr-Latn": "sr",
    "sv": "sv-SE", "tr": "tr-TR",
}

# ISO alpha-3 (pricing.json) → alpha-2 (Google Play regions).
ALPHA3 = {
    "USA": "US", "CAN": "CA", "AUS": "AU", "NZL": "NZ", "GBR": "GB", "CHE": "CH", "NOR": "NO", "SWE": "SE",
    "DNK": "DK", "FIN": "FI", "ISL": "IS", "IRL": "IE", "NLD": "NL", "LUX": "LU", "AUT": "AT", "DEU": "DE",
    "BEL": "BE", "SGP": "SG", "ARE": "AE", "ISR": "IL", "JPN": "JP", "FRA": "FR", "ESP": "ES", "ITA": "IT",
    "PRT": "PT", "GRC": "GR", "KOR": "KR", "TWN": "TW", "HKG": "HK", "SAU": "SA", "QAT": "QA", "EST": "EE",
    "LVA": "LV", "LTU": "LT", "SVN": "SI", "SVK": "SK", "MLT": "MT", "CYP": "CY", "HRV": "HR", "POL": "PL",
    "CZE": "CZ", "HUN": "HU", "ROU": "RO", "BGR": "BG", "CHL": "CL", "MEX": "MX", "BRA": "BR", "CHN": "CN",
    "MYS": "MY", "THA": "TH", "TUR": "TR", "CRI": "CR", "URY": "UY",
}


def money(currency, amount):
    amount = Decimal(amount)
    units = int(amount)
    nanos = int((amount - units) * 1_000_000_000)
    return {"currencyCode": currency, "units": str(units), "nanos": nanos}


def load_files():
    pricing = json.loads(PRICING.read_text())
    texts = json.loads(TEXTS.read_text())
    problems = []
    for folder in texts:
        if folder not in LANGUAGES:
            problems.append(f"langue sans code Google Play : {folder}")
    for tier in pricing["tiers"]:
        for t in tier["territories"]:
            if t not in ALPHA3:
                problems.append(f"pays inconnu : {t}")
    for play_id, (ios_id, *_rest) in PRODUCTS.items():
        for folder, value in texts.items():
            sub = value.get("subscriptions", {}).get(ios_id)
            if not sub:
                problems.append(f"{folder}: pas de texte pour {ios_id}")
            elif len(sub["name"]) > 55 or len(sub["description"]) > 80:
                problems.append(f"{folder}/{ios_id}: nom > 55 ou description > 80 caractères")
    return pricing, texts, problems


def listings(texts, ios_id):
    out = []
    for folder, value in texts.items():
        sub = value["subscriptions"][ios_id]
        out.append({"languageCode": LANGUAGES[folder], "title": sub["name"], "description": sub["description"]})
    if not any(l["languageCode"] == "en-US" for l in out):
        en = {"Artura_yearly": ("Artura Pro yearly", "Unlocks every feature of Artura Pro"),
              "Artura_monthly": ("Artura Pro monthly", "Unlocks every feature of Artura Pro"),
              "Artura_yearly_gift": ("Artura Pro yearly gift", "Yearly plan with a welcome discount")}[ios_id]
        out.append({"languageCode": "en-US", "title": en[0], "description": en[1]})
    return out


def tier_price(region, kind, pricing):
    if kind == "monthly":
        return MONTHLY_USD
    for tier in pricing["tiers"]:
        if region in {ALPHA3[t] for t in tier["territories"]}:
            return tier[kind]
    return pricing["default"][kind]


class Play:
    def __init__(self, dry):
        from google.oauth2 import service_account
        from google.auth.transport.requests import AuthorizedSession
        info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
        creds = service_account.Credentials.from_service_account_info(
            info, scopes=["https://www.googleapis.com/auth/androidpublisher"])
        self.session = AuthorizedSession(creds)
        self.dry = dry
        self._converted = {}
        self.regions_version = REGIONS_VERSION

    def call(self, method, path, body=None, params=None, write=True):
        if write and self.dry:
            print(f"  [simulation] {method} {path}")
            return {}
        r = self.session.request(method, API + path, json=body, params=params)
        if r.status_code == 404 and method == "GET":
            return None
        if not r.ok:
            raise RuntimeError(f"{method} {path} → {r.status_code}: {r.text[:800]}")
        return r.json() if r.text else {}

    def converted(self, usd):
        """Price of `usd` US dollars in every Google Play region: {region: Money}."""
        if usd not in self._converted:
            data = self.call("POST", "/pricing:convertRegionPrices", {"price": money("USD", usd)}, write=False)
            # The regions (and their currencies) change over time: use the version Google answered with.
            self.regions_version = data.get("regionVersion", {}).get("version", REGIONS_VERSION)
            self._converted[usd] = {code: v["price"] for code, v in data["convertedRegionPrices"].items()}
        return self._converted[usd]

    def regional_prices(self, kind, pricing):
        regions = self.converted("1.00").keys()
        configs = []
        for region in sorted(regions):
            usd = tier_price(region, kind, pricing)
            price = self.converted(usd)[region]
            if price["currencyCode"] in pricing.get("exact_price_currencies", []):
                price = money(price["currencyCode"], usd)  # 29.99 € stays 29.99 €
            configs.append({"regionCode": region, "newSubscriberAvailability": True, "price": price})
        return configs


def run(dry):
    pricing, texts, problems = load_files()
    if problems:
        sys.exit("\n".join(problems))
    play = Play(dry)
    for play_id, (ios_id, kind, plan_id, period, trial) in PRODUCTS.items():
        print(f"\n== {play_id} ({period}, essai {trial})")
        regional = play.regional_prices(kind, pricing)
        sample = {c["regionCode"]: c["price"] for c in regional}
        for r in ("US", "FR", "DE", "BR", "IN"):
            if r in sample:
                p = sample[r]
                print(f"  {r}: {p['units']}.{str(p.get('nanos', 0)).zfill(9)[:2]} {p['currencyCode']}")
        base_plan = {
            "basePlanId": plan_id,
            "regionalConfigs": regional,
            "autoRenewingBasePlanType": {
                "billingPeriodDuration": period,
                "gracePeriodDuration": "P3D",
                "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE",
                "prorationMode": "SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE",
                "legacyCompatible": True,
            },
        }
        body = {"packageName": PACKAGE, "productId": play_id, "listings": listings(texts, ios_id), "basePlans": [base_plan]}
        params = {"regionsVersion.version": play.regions_version}
        existing = play.call("GET", f"/subscriptions/{play_id}", write=False)
        if existing is None:
            print("  création de l'abonnement")
            play.call("POST", "/subscriptions", body, {**params, "productId": play_id})
        else:
            print("  mise à jour (noms, descriptions, prix des nouveaux abonnés)")
            plans = existing.get("basePlans", [])
            for p in plans:
                if p["basePlanId"] == plan_id:
                    p["regionalConfigs"] = regional
            body["basePlans"] = plans or [base_plan]
            play.call("PATCH", f"/subscriptions/{play_id}", body,
                      {**params, "updateMask": "listings,basePlans", "allowMissing": "true"})
        plan_path = f"/subscriptions/{play_id}/basePlans/{plan_id}"
        play.call("POST", f"{plan_path}:activate", {"packageName": PACKAGE, "productId": play_id, "basePlanId": plan_id})

        offers = play.call("GET", f"{plan_path}/offers", write=False) if existing else None
        if not any(o.get("offerId") == "trial" for o in (offers or {}).get("subscriptionOffers", [])):
            print(f"  offre d'essai gratuit de {trial}")
            offer = {
                "packageName": PACKAGE, "productId": play_id, "basePlanId": plan_id, "offerId": "trial",
                "phases": [{"recurrenceCount": 1, "duration": trial,
                            "regionalConfigs": [{"regionCode": c["regionCode"], "free": {}} for c in regional]}],
                "targeting": {"acquisitionRule": {"scope": {"thisSubscription": {}}}},
                "regionalConfigs": [{"regionCode": c["regionCode"], "newSubscriberAvailability": True} for c in regional],
            }
            play.call("POST", f"{plan_path}/offers", offer, {**params, "offerId": "trial"})
        play.call("POST", f"{plan_path}/offers/trial:activate",
                  {"packageName": PACKAGE, "productId": play_id, "basePlanId": plan_id, "offerId": "trial"})
    print("\nTerminé." + (" (simulation : rien n'a été écrit)" if dry else ""))


if __name__ == "__main__":
    if "--check" in sys.argv:
        _, _, problems = load_files()
        print("\n".join(problems) or "Fichiers OK")
        sys.exit(1 if problems else 0)
    run("--dry-run" in sys.argv)
