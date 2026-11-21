# Artura

Application iOS (SwiftUI, iOS 17+) : un chef-d'œuvre par jour, son histoire en quelques minutes, et des mini-jeux pour s'en souvenir.

- **Bundle ID** : `com.vikstudios.artura`
- **Langue** : français
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
| `Artura/Onboarding` | Les écrans d'accueil, du premier écran au paywall |
| `Artura/Learn` | Lecture d'un cours bloc par bloc, quiz |
| `Artura/Main` | Onglets Aujourd'hui, Explorer, Jeux, Profil |
| `Artura/Games` | Zoom mystère, Chronologie, Vrai ou faux, Palette |
| `Artura/Resources/content.json` | Œuvres, cours, quiz, anecdotes, courants |

## Contenu

Tout le contenu est dans `Artura/Resources/content.json`. Ajouter une œuvre = ajouter une entrée dans `artworks` et une image `art_<id>` dans `Assets.xcassets`.

## Abonnement (StoreKit 2)

Produits attendus :

- `com.vikstudios.artura.pro.yearly` (essai gratuit de 3 jours)
- `com.vikstudios.artura.pro.monthly` (essai gratuit de 3 jours)

`Artura/Artura.storekit` permet de tester les achats dans le simulateur sans App Store Connect ; le schéma partagé le référence déjà. **Les prix qu'il contient (29,99 et 4,99) sont des valeurs de test**, à remplacer par les vrais tarifs, puis à créer à l'identique dans App Store Connect.

## Connexion

*Sign in with Apple* est branché (capacité déclarée dans `Artura.entitlements`), avec une option « Continuer sans compte ». L'identifiant Apple est seulement mémorisé sur l'appareil : il n'y a pas encore de serveur.

## À faire avant une mise en ligne

- Remplacer la note « 4,8 » et les trois avis d'exemple de l'onboarding (`ReviewsScreen`) par de vraies données.
- Fixer les prix et créer les produits dans App Store Connect.
- Vérifier les licences des reproductions (Wikimedia Commons) et celle des illustrations générées.
- Widget « œuvre du jour » : non inclus dans cette version.
- Histoires audio : annoncées dans l'offre Pro, pas encore implémentées.

## Crédits

- Police [Figtree](https://fonts.google.com/specimen/Figtree), licence OFL (voir `Artura/Fonts/LICENSE_FONT`).
- Reproductions d'œuvres : Wikimedia Commons.
