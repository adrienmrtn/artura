# Artura

Application iOS (SwiftUI, iOS 17+) : un chef-d'œuvre par jour, son histoire en quelques minutes, et des mini-jeux pour s'en souvenir.

- **Bundle ID** : `com.vikstudios.artura`
- **Langue** : onboarding en anglais, reste de l'appli (cours, jeux, profil, notifications) en français
- **Dépendances** : aucune (SwiftUI, StoreKit 2, AuthenticationServices, UserNotifications)

## Ouvrir le projet

1. Ouvrir `Artura.xcodeproj` avec **Xcode 16 ou plus récent**.
2. Dans *Signing & Capabilities*, choisir ton équipe de développement.
3. Lancer sur un simulateur iPhone.

Le projet utilise un dossier synchronisé : tout fichier ajouté dans `Artura/` est pris en compte sans toucher au fichier projet.
Si le projet ne s'ouvre pas, `project.yml` permet de le régénérer avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen` à la racine).

## Organisation

| Dossier | Contenu |
|---|---|
| `Artura/App` | Point d'entrée, bascule onboarding / appli |
| `Artura/Core` | Thème (couleurs, police Figtree, formes), composants, haptique |
| `Artura/Data` | Modèles, contenu embarqué, profil et progression (stockés sur l'appareil) |
| `Artura/Services` | Rappels (notifications locales) et abonnement Artura Pro (StoreKit 2) |
| `Artura/Onboarding` | Les écrans d'accueil, du premier écran à l'essai gratuit (`OnboardingFlow.swift` donne l'ordre) |
| `Artura/Learn` | Lecture d'un cours bloc par bloc, quiz |
| `Artura/Main` | Onglets Aujourd'hui, Explorer, Jeux, Profil |
| `Artura/Games` | Zoom mystère, Chronologie, Vrai ou faux, Palette |
| `Artura/Resources/content.json` | Œuvres, cours, quiz, anecdotes, courants |

## Onboarding

L'ordre des écrans est l'énumération `OnbStep` dans `Artura/Onboarding/OnboardingFlow.swift`. L'onboarding est rédigé en anglais ; l'extrait de cours qu'il affiche vient de `Artura/Resources/onboarding_en.json`, et les boutons du cours passent en anglais grâce à `LessonLanguage` (`Artura/Learn/LessonLanguage.swift`). Les briques communes (personnage de la Joconde, bulle, texte qui s'écrit, mur de tableaux) sont dans `OnboardingKit.swift`.

Pour ouvrir directement un écran en build Debug, ajouter des arguments de lancement au schéma (*Product › Scheme › Edit Scheme › Run › Arguments*) :

| Argument | Effet |
|---|---|
| `-onbStep graph` | Démarre l'onboarding à cette étape (nom d'un cas de `OnbStep`) |
| `-onbName Max` | Prénom utilisé dans les écrans |
| `-onbPreviewOffer YES` | Affiche les écrans d'essai avec des prix d'exemple, sans StoreKit |
| `-onbGiftOpen YES` | Écran cadeau déjà ouvert |
| `-onbExitOffer YES` | Ouvre l'offre « 7 jours » dès l'écran d'essai |
| `-onbLine 2` | Réplique affichée d'abord sur un écran où la Joconde parle (0 = la première) |
| `-onbWidgetHome YES` | Écran du widget en version « écran d'accueil » |
| `-noSplash YES` | Saute l'écran de lancement |
| `-holdSplash YES` | Garde l'écran de lancement affiché |
| `-skipOnboarding YES` | Ouvre directement l'appli |

## Build automatique

`.github/workflows/build.yml` compile l'appli pour le simulateur à chaque push sur une branche `claude/**`. Si le message du commit contient `[captures]`, le même job lance l'appli dans un simulateur et prend une capture de chaque écran de l'onboarding (visibles dans les logs du job).

## Contenu

Tout le contenu est dans `Artura/Resources/content.json`. Ajouter une œuvre = ajouter une entrée dans `artworks` et une image `art_<id>` dans `Assets.xcassets`.

## Abonnement (StoreKit 2)

Produits attendus :

- `com.vikstudios.artura.pro.yearly` (essai gratuit de 3 jours)
- `com.vikstudios.artura.pro.monthly` (essai gratuit de 3 jours)
- `com.vikstudios.artura.pro.yearly.trial7` (même abonnement annuel, essai gratuit de 7 jours : l'offre de dernière minute de l'onboarding)

`Artura/Artura.storekit` permet de tester les achats dans le simulateur sans App Store Connect ; le schéma partagé le référence déjà. **Les prix qu'il contient (29,99 et 4,99) sont des valeurs de test**, à remplacer par les vrais tarifs, puis à créer à l'identique dans App Store Connect.

## Connexion

*Sign in with Apple* est branché (capacité déclarée dans `Artura.entitlements`), avec une option « Continuer sans compte ». La connexion Google passe par OAuth 2 dans la fenêtre d'authentification du système, sans bibliothèque externe. Dans les deux cas l'identifiant du compte est seulement mémorisé sur l'appareil : il n'y a pas encore de serveur.

## À faire avant une mise en ligne

- Remplacer le contenu de `SocialProof` (`OnboardingKit.swift` : « 100 000 apprenants », « 4,8 », les trois avis) par les vrais chiffres et de vrais avis de l'appli.
- L'onboarding annonce trois choses qui n'existent pas encore : la photo d'une œuvre expliquée par Artura, le widget « œuvre du jour » (écran verrouillé et accueil), et « près de 400 tableaux et artistes en un an » (le contenu compte aujourd'hui 8 œuvres).
- Connexion Google : renseigner `GoogleAuth.clientID` (`Artura/Services/GoogleAuth.swift`) avec un identifiant client OAuth de type iOS créé dans Google Cloud Console. Sans lui, le bouton n'apparaît qu'en build Debug.
- Renseigner `Legal.privacy` (`OnboardingPaywall.swift`) avec l'adresse de la politique de confidentialité.
- Fixer les prix et créer les produits dans App Store Connect.
- Vérifier les licences des reproductions (Wikimedia Commons) et celle des illustrations générées.
- Widget « œuvre du jour » : non inclus dans cette version.
- Histoires audio : annoncées dans l'offre Pro, pas encore implémentées.

## Crédits

- Police [Figtree](https://fonts.google.com/specimen/Figtree), licence OFL (voir `Artura/Fonts/LICENSE_FONT`).
- Reproductions d'œuvres (`art_*`, `wall_*`) : Wikimedia Commons, œuvres du domaine public.
