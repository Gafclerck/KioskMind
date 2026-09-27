# KioskMind

Application Flutter de gestion de caisse, stock et alertes pour borne.

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

Le detail de chaque couche est decrit dans les `.gitkeep` des dossiers.

## Prerequis

- Flutter 3.44.6 (stable)
- Dart 3.12.2

## Commandes

```bash
flutter pub get      # dependances
flutter analyze      # lint et analyse statique
flutter test         # tests
flutter run          # lancer l'application
```

Pour un test unique :

```bash
flutter test test/widget_test.dart
flutter test --plain-name "app builds and exposes its title"
```

Sous WSL, le SDK Flutter doit etre invoque via Windows, car ses scripts bash
sont stockes en CRLF :

```bash
cmd.exe /c "cd /d D:\kiosk_mind && flutter analyze"
```

## Structure

```text
lib/
  main.dart    point d'entree, minimal
  app.dart     widget racine, theme, router a terme
  core/        code partage, uniquement si utilise par plusieurs features
  features/    une dossier par feature : presentation / domain / data
```

Regle de dependance : `presentation` et `data` dependent de `domain`, `domain`
ne depend d'aucune couche exterieure.

## Workflow Git

- `main` et `develop` sont proteges, aucun travail direct dessus.
- Une branche dediee par tache : `feature/<nom>`, `fix/<nom>`, `refactor/<nom>`.
- Commits conventionnels, une ligne, un changement logique par commit :
  `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `build:`, `ci:`.
- Validation `flutter analyze` puis `flutter test` avant toute Pull Request.

La CI (.github/workflows/ci.yml) execute ces memes verifications sur chaque push
et Pull Request visant `main` ou `develop`.
