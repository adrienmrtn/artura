# Artura pour Android

Version Android d'Artura (Kotlin, Jetpack Compose, Android 8.0+). Même appli que la version iOS : mêmes écrans, mêmes textes, même contenu, même compte en ligne.

- **Package** : `com.vikstudios.artura`
- **Contenu partagé avec iOS** : les images (`Artura/Assets.xcassets`), la police, `content*.json`, `lessons.*.json`, `palettes.json` et les traductions (`*.lproj/Localizable.strings`) ne sont **pas copiés** dans ce dossier : la compilation les reprend dans `../Artura` (tâches `syncIosResources` et `syncIosAssets` de `app/build.gradle.kts`). Une œuvre ou une traduction ajoutée côté iOS arrive donc aussi sur Android.

## Compiler

Android Studio (Ladybug ou plus récent) : ouvrir le dossier `android/`. En ligne de commande :

```bash
cd android && ./gradlew :app:assembleDebug
```

L'APK est dans `app/build/outputs/apk/debug/`.

## Organisation (miroir du dossier iOS)

| Dossier (`app/src/main/java/com/vikstudios/artura/`) | Équivalent iOS |
|---|---|
| `app` | `App` : activité, racine, écran de lancement, objets partagés (`AppGraph`), arguments de debug, `FullScreenCover` |
| `core` | `Core` : couleurs, police, composants, haptique, traductions (`L()`) |
| `data` | `Data` : modèles, contenu, catalogue en ligne, profil |
| `services` | `Services` : abonnement (Google Play Billing), compte (Supabase + Google), rappels, statistiques |
| `onboarding`, `feed`, `learn`, `review`, `games`, `main`, `widget` | dossiers du même nom |

## Règles de portage (pour garder les deux versions identiques)

- **Textes** : toujours `L("texte anglais")` ou `L("%@ jours", "$n")`, avec exactement la clé anglaise utilisée dans le Swift. Les traductions viennent des fichiers iOS ; ne jamais écrire de texte en dur.
- **Couleurs, polices** : `Palette.*`, `AType.*`, `figtree(taille, FontWeight.X)`. Les tailles en points iOS deviennent des `dp`/`sp` à l'identique.
- **Composants** (`core/Components.kt`) : `PillButton` (`.primary`, `.secondary` = `PillStyle.Secondary`, `.dark`), `Modifier.pressable {}` (`.buttonStyle(.pressable)`), `TextLinkButton`, `TagPill`, `ProgressTrack`, `CheckBadge`, `StreakChip`, `OptionRow`, `ArtImage(name, …)` (nom d'image ou URL du catalogue), `SkyHeader`, `Modifier.appearUp()`.
- **Onboarding** (`onboarding/OnboardingKit.kt`) : `Modifier.enter(ordre)`, `Mascot`, `MascotBubble`, `MascotTalkScreen`, `FloatingSpace`, `FloatingWall`, `RaysBackground`, `Sparkle`, `ChoiceRow`, `OnbScaffold`, `StoryScaffold`, `HeroScaffold`, `rememberClock()` (remplace `TimelineView`).
- **Données** : `LocalContent.current`, `LocalUser.current`, `LocalPro.current`. Le profil est immuable : `user.update { it.copy(...) }`.
- **Écrans plein écran** (`.fullScreenCover`) : `FullScreenCover(visible, onDismiss) { … }` (`app/Covers.kt`). **Feuilles** (`.sheet`) : `ModalBottomSheet` de Material 3.
- **Bords de l'écran** : l'appli dessine sous les barres système ; chaque écran ajoute `statusBarsPadding()` / `navigationBarsPadding()` là où iOS respecte la zone sûre.
- **Icônes** : SF Symbols → `Icons.Rounded.*` (material-icons-extended) les plus proches.
- **Haptique** : `Haptics.tap()`, `press()`, `soft()`, `selection()`, `success()`… aux mêmes moments qu'iOS.
- **Statistiques** : `Analytics.track("nom", mapOf(...))` avec les mêmes noms d'événements et de propriétés qu'iOS.

## Captures d'écran (sans téléphone)

Les écrans peuvent être rendus sur l'ordinateur (Robolectric + Roborazzi) : chaque test de `app/src/test` appelle `capture("nom") { Écran() }` et l'image est écrite dans `android/captures/nom.png`.

```bash
cd android && ./gradlew :app:testDebugUnitTest -Proborazzi.test.record=true
```

## Arguments de debug

Les mêmes qu'iOS, passés en « extras » au lancement (build Debug uniquement) :

```bash
adb shell am start -n com.vikstudios.artura/.app.MainActivity --es demoProfile YES --es appTab review
```

## Différences avec iOS

- **Abonnement** : Google Play Billing. Produits à créer dans la Play Console (abonnements, un forfait de base + une offre d'essai gratuit chacun) : `artura_yearly` (essai 3 jours), `artura_monthly` (sans essai), `artura_yearly_gift` (annuel −40 %, essai 7 jours). Play n'accepte pas les majuscules des identifiants iOS. Tant qu'ils n'existent pas, les écrans d'essai affichent des prix d'exemple.
- **Connexion** : Google uniquement (pas de « Se connecter avec Apple »), plus « Continuer sans compte ». Le compte Supabase et la progression sont les mêmes que sur iPhone. À configurer : `GoogleAuth.webClientId` (`services/GoogleAuth.kt`) avec un identifiant client OAuth de type **Web** ; créer aussi un client **Android** (package + empreinte SHA-1 du certificat de signature) dans le même projet Google Cloud, et ajouter l'identifiant Web dans Supabase › Authentication › Google › Client IDs.
- **Rappels** : notifications locales (`AlarmManager`), permission demandée sur Android 13+.
- **Widget** : widget d'écran d'accueil (Jetpack Glance) « Artwork of the day ».
- **Statistiques** : même table `app_events` ; `os_version` vaut « Android 14 », etc.

## Publication sur Google Play (automatisée)

- **Clé de debug partagée** : `app/debug.keystore` est commitée exprès, pour que toutes les versions de debug aient la même empreinte SHA-1 (`E4:61:8E:58:36:3F:6C:E9:1B:C9:55:9F:54:64:29:1E:74:10:91:A9`), déclarée dans Google Cloud pour la connexion Google.
- **Clé d'envoi** (`artura-upload.jks`, jamais commitée) : dans les secrets GitHub `ANDROID_KEYSTORE_B64` (fichier en base64) et `ANDROID_KEYSTORE_PASSWORD`. SHA-1 : `3A:C9:3F:69:3B:24:1D:AD:49:88:80:F6:33:2B:DE:F5:60:55:F2:68`.
- **Workflow « Android release »** : compile le `.aab` signé (dans les Artifacts) ; option « upload » pour l'envoyer en test interne (après la première version envoyée à la main).
- **Workflow « Google Play store »** : lancé par « [play:dry] » (simulation) ou « [play] » dans un message de commit, ou à la main une fois sur la branche principale.
  - **Fiche du Store** (`play/play_listing.py`) : nom, description courte et complète dans toutes les langues, reprises de `fastlane/metadata` (sans les lignes propres à Apple). Modifier ces textes met à jour l'App Store et Google Play.
  - **Abonnements** (`play/play_subscriptions.py`) : crée ou met à jour les trois abonnements, leurs essais gratuits, leurs prix par pays (mêmes paliers que l'App Store, `fastlane/subscriptions/pricing.json` ; mensuel 6,99 $ converti) et leurs textes dans toutes les langues (`fastlane/subscriptions/localizations.json`). Secret : `PLAY_SERVICE_ACCOUNT_JSON`.
