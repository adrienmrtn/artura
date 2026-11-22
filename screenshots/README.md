# Captures App Store (version B, 29 langues)

Les captures ne sont pas stockées dans le repo : le workflow « App Store screenshots » les génère
(6 écrans × 29 langues, JPEG 1290 × 2796, iPhone 6,9"), les met en téléchargement, puis les envoie
sur App Store Connect. Un aperçu en anglais est dans `preview/`.

- Titres marketing : `headlines.json` (un jeu par langue App Store).
- Tout le reste (boutons, onglets, leçon sur La Nuit étoilée, jeux, bulle de la Joconde) vient
  des traductions de l'app : `Artura/Resources/<langue>.lproj/Localizable.strings` et `content.<langue>.json`.
- Coréen : l'app n'est pas traduite en coréen, seuls les titres le sont.
- Écran 5 : vraie capture d'écran d'accueil, en anglais dans toutes les langues.

## En local

```
cd screenshots
npm install
pip install playwright && python -m playwright install chromium
ARTURA_APP=../Artura/Resources SHOTS_OUT=../fastlane/screenshots python render.py          # toutes les langues
ARTURA_APP=../Artura/Resources SHOTS_OUT=../fastlane/screenshots python render.py fr-FR    # une seule
```

## iPad 13" (anglais seulement)

Le workflow « App Store screenshots iPad (English) » lance l'appli (démo) sur un simulateur « iPad Pro 13-inch »
et prend de vraies captures plein écran (2064 × 2752, sans cadre ni iPhone). Il peut ensuite les envoyer avec les
captures iPhone en-US (`fastlane screenshots_en`) : l'envoi remplace toutes les captures en-US, d'où les deux formats ensemble.
