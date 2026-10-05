# KioskMind

Application Flutter de gestion de caisse, stock et alertes pour borne.

## Prerequis

- Flutter 3.44.6 (stable)
- Dart 3.12.2

## Installation

```bash
git clone https://github.com/Gafclerck/KioskMind.git
cd KioskMind
flutter pub get
cp .env.example .env
```

## Variables d'environnement

Les reglages propres a ta machine (cles rodium, gemini, upload d'avatar
Cloudinary) se trouvent dans `.env`, qui n'est pas versionne :
`.env.example` fait foi pour la liste et le format.

```bash
cp .env.example .env   # une seule fois, puis renseigner les valeurs
dart run tool/check_env.dart   # signale les placeholders et les cles manquantes
```

Les valeurs sont injectees a la compilation. Sans elles, l'application
demarre quand meme et signale les fonctions concernees comme non configurees.

| Variable | Role |
|---|---|
| `VOICE_USE_MOCKS` | `true` pour faire tourner l'assistant vocal sans micro |
| `VOICE_ENABLE_CLOUD` | `false` pour garder l'interpretation vocale hors ligne |
| `RODIUM_API_KEY`, `RODIUM_MODEL`, `RODIUM_BASE_URL` | Passerelle vocale cloud |
| `GEMINI_API_KEY` | Interpretation d'intents Google |
| `CLOUDINARY_CLOUD_NAME` | Cloud qui heberge les photos de profil |
| `CLOUDINARY_UPLOAD_PRESET` | Preset d'upload **unsigned** Cloudinary |

## Commandes

```bash
flutter pub get      # dependances
flutter analyze      # lint et analyse statique
flutter test         # tests
dart format lib test # formatage
flutter run --dart-define-from-file=.env   # lancer l'application
```

Unittest :

```bash
flutter test test/widget_test.dart
```

Release :

```bash
flutter build apk --dart-define-from-file=.env --release
```

## Architecture

Clean Architecture, structure feature-first. Chaque feature est decoupee en
`presentation`, `domain` et `data`. Le code reellement partage vit dans
`lib/core/`.

| Feature | Role |
|---|---|
| `auth/` | Login, inscription, profil boutique |
| `products_stock/` | Produits et mouvements de stock, offline-first sur Firestore |
| `sales/` | Ventes, historique, tableau de bord |
| `alerts_predictions/` | Alertes de stock bas et prediction de rupture, push FCM |
| `voice_assistant/` | Orchestration vocale, interpretation d'intents |
| `clients_credit/` | Clients, dettes, remboursements |
| `export_reporting/` | Export achats et ventes vers Excel |

Regle de dependance : `presentation` et `data` dependent de `domain`, qui ne
depend d'aucune couche exterieure. La logique metier et l'acces aux donnees
n'ont pas leur place dans un widget.

## Structure

```text
lib/
  main.dart    point d'entree, minimal
  app.dart     widget racine, theme
  core/        code partage, uniquement si utilise par plusieurs features
  features/    un dossier par feature : presentation / domain / data
```

## Workflow de contribution

- `main` et `develop` sont proteges : aucun travail direct dessus.
- Une branche dediee par tache : `feature/<nom>`, `fix/<nom>`, `refactor/<nom>`.
- Commits conventionnels, une seule ligne, un changement logique par commit :
  `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `build:`, `ci:`.
- Validation `dart format`, `flutter analyze` puis `flutter test` avant toute
  Pull Request.

## CI

`.github/workflows/ci.yml` execute `flutter pub get`, `flutter analyze` et
`flutter test` sur chaque push et chaque Pull Request visant `main` ou
`develop`. Le formatage n'y est pas verifie.
