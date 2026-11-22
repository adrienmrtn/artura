#!/usr/bin/env python3
"""Vérifie les textes de fastlane/metadata avant l'envoi (limites App Store Connect + lien EULA)."""
import pathlib
import sys

EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
LIMITS = {"name": 30, "subtitle": 30, "promotional_text": 170, "keywords": 100,
          "description": 4000, "release_notes": 4000}
root = pathlib.Path(__file__).parent / "metadata"
errors = []
locales = sorted(p for p in root.iterdir() if p.is_dir())
for loc in locales:
    for key, limit in LIMITS.items():
        f = loc / f"{key}.txt"
        if not f.exists():
            errors.append(f"{loc.name}: {key}.txt manquant")
            continue
        text = f.read_text(encoding="utf-8")
        if len(text) > limit:
            errors.append(f"{loc.name}: {key} fait {len(text)} caractères (max {limit})")
        if not text.strip():
            errors.append(f"{loc.name}: {key} est vide")
    d = loc / "description.txt"
    if d.exists() and EULA not in d.read_text(encoding="utf-8"):
        errors.append(f"{loc.name}: lien EULA absent de la description")
print(f"{len(locales)} langues contrôlées")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print("OK")
