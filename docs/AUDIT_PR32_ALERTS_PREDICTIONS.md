# Audit PR #32 — `feat(prediction): alert and prediction`

> **Date :** 2026-10-06 · **Branche :** `feature/alertPrediction` · **Commit audité :** `f0c5e57` · **Base :** `origin/develop`
> **Périmètre :** 35 fichiers, +1758 / -326 lignes
> **Worktree de test :** `/mnt/d/kiosk_mind_pr32` · **Harness d'état :** `/tmp/opencode/audit_harness/test_uc13_uc14.py`

---

## 1. Ce qui est réellement implémenté

### Serveur — `functions/main.py` (220 lignes)

| US | Fonction | Mécanisme | État |
|---|---|---|---|
| **UC13** | `verifier_stock` (L49) | Trigger `on_document_updated` sur `users/{uid}/products/{id}` | Fonctionnel, **3 bugs d'état** (§3) |
| **UC14** | `predictions_quotidiennes` (L83) | Schedule `every day 06:00`, moyenne des ventes sur 7 jours via `dailyStats` | Fonctionnel, **2 bugs** (§3) |
| Notifications | `_envoyer_notification` (L189) | FCM multicast, i18n fr/en, langue lue sur `users/{uid}.language` | Fonctionnel, **perte silencieuse** (§3.5) |

Points **justes** et à conserver :

- ID d'alerte déterministe `{productId}_{type}` → écritures idempotentes (L145).
- Anti-spam : une seule notification par occurrence ACTIVE (L156).
- Pas de division par zéro : `total_vendu == 0` → résolution + `continue` (L105).
- Pas d'index composite requis : `orderBy` retiré, tri côté Dart — la requête 2×`where` est en equality-only (`alert_repository_impl.dart` L18).
- `dailyStats.qtyByProduct` est bien clé par `productId` côté app (`sales_remote_data_source.dart` L366) → **cohérent** avec `qty_par_produit.get(product_id)`.
- Vente + décrément stock + `dailyStats` écrits dans le **même batch** → le trigger part sur le bon état.

### Client Flutter — `lib/features/alerts_predictions/`

Architecture clean (domain / data / presentation), 13 fichiers. FCM gère les 3 cas
(premier plan, arrière-plan, app fermée) + `onTokenRefresh` + `onBackgroundMessage`
(`lib/main.dart`). Android : permission `POST_NOTIFICATIONS` ajoutée, desugaring
`2.1.4` ajouté (requis par `flutter_local_notifications`). Cloche de navigation
ajoutée sur le dashboard des ventes.

---

## 2. Validation exécutée

| Contrôle | Résultat |
|---|---|
| `flutter analyze` (tout le PR) | **0 erreur**, 1 warning — import inutile `alerts_repository.dart` dans `alerts_providers.dart:7` |
| `dart format --set-exit-if-changed` | **`alert_repository_impl.dart` non formaté** (fichier 100 % ajouté par le PR)¹ |
| `py_compile functions/main.py` | OK |
| `flutter test test/products_stock/stock_overview_provider_test.dart` | **+6 tests passés** |
| Harness d'exécution `main.py` (Firestore/FCM fake en mémoire) | **5 bugs prouvés par exécution** |
| `flutter test test/routing`, `test/sales` | ❌ **bloqué** : `C:\` plein à 100 % (errno 112) — problème d'environnement, pas de code |
| Tests ajoutés par le PR | ❌ **0** — le repo compte 80+ fichiers de test |

¹ `app_router.dart` est aussi non formaté, mais **c'était déjà le cas sur `develop`** — pas imputable au PR.

---

## 3. Bloquants (corriger AVANT merge)

### 3.1 — `_kUseEmulator = true` est commité

`lib/features/alerts_predictions/presentation/providers/alerts_providers.dart:16`
+ IP d'émulateur hardcodée `10.0.2.2` (L38).

**Impact :** en production l'app lit une instance Firestore **secondaire pointant sur
un émulateur Android inexistant** → le flux d'alertes est en erreur permanente pour
tout utilisateur. Le README du feature (L108) le dit explicitement : *« Remettre
`_kUseEmulator = false` avant de committer »* — ce qui n'a pas été fait.

**Fix :** passer à `false`, ou mieux, sortir ce flag du code produit (config debug
vs release).

### 3.2 — Branche `NEGATIVE_STOCK` jamais résolue — **prouvé**

`functions/main.py` L74-76 : la branche `elif stock <= seuil` résout `PREDICTED` mais
**oublie `NEGATIVE_STOCK`**.

```
[4] -2 -> 8 (reappro, seuil 10) : NEGATIVE doit passer RESOLVED
  FAIL  NEGATIVE_STOCK RESOLVED  -> ACTIVE   <-- BUG
```

L'utilisateur se retrouve avec **2 alertes actives simultanées** pour le même produit
(`NEGATIVE_STOCK` fantôme + `LOW_STOCK`), et la notification « stock négatif,
vérifiez vos ventes » reste active alors que le stock est réapprovisionné. Le
scénario de `scripts/test_manual.py` ne l'a jamais détecté car il saute l'étape
intermédiaire (il passe de `-2` directement à `25`).

**Fix :** ajouter `_resoudre_alerte(db, product_id, TYPE_NEGATIVE)` dans la branche `elif`.

### 3.3 — `PREDICTED_STOCKOUT` non résolue lors d'un réappro — **prouvé**

`functions/main.py` L77-79 : la branche `else` (stock > seuil) résout `LOW_STOCK` +
`NEGATIVE` mais **pas `PREDICTED`**.

```
[5] PREDICTED_STOCKOUT RESOLVED apres reappro -> ACTIVE   <-- BUG
```

Après un réappro complet, l'alerte « rupture prévue dans 2 jours » reste affichée
**jusqu'au lendemain 06:00** (seule UC14 la résout). Comme le stock vient d'être
rechargé, c'est une **information fausse** pendant jusqu'à 24 h.

**Fix :** résoudre les 3 types dans la branche `else`.

### 3.4 — `functions/requirements.txt` est en **UTF-16LE avec BOM** — prouvé

```
file: Unicode text, UTF-16, little-endian, CRLF
first bytes: b'\xff\xfea\x00'   utf-8 decode: FAIL
```

- `pip` tolère le BOM UTF-16 (auto_decode), **mais** à partir de **Python 3.14 le
  buildpack Cloud Run utilise `uv` par défaut**, et `uv` n'accepte que du UTF-8 →
  **échec probable du build au déploiement**.
- Casse aussi grep, Dependabot, les éditeurs et la revue GitHub.

**Fix :** ré-encoder en UTF-8 sans BOM (+ CRLF→LF) :

```bash
iconv -f UTF-16 -t UTF-8 functions/requirements.txt > /tmp/r.txt && mv /tmp/r.txt functions/requirements.txt
```

### 3.5 — Échec FCM silencieux → notification perdue à jamais — **prouvé**

`functions/main.py` L174-176 : `notifiedAt` est écrit **même si l'envoi a échoué**
(le `try/except` L211-219 avale l'erreur, et le retour anticipé « Pas de token FCM »
aussi).

```
[8] notifiedAt ecrit malgre l'echec => jamais de retry  PASS (constat)
[9] notifiedAt lu dans une condition                   FAIL
```

Deuxième constat : **`notifiedAt` n'est jamais lu** dans tout le fichier — alors que
le docstring L153 affirme *« notifie seulement si ce n'est pas déjà fait (via
notifiedAt) »*. La logique repose en réalité uniquement sur `status == ACTIVE` :
documentation et implémentation divergent, et il n'y a **aucun mécanisme de retry**.

**Fix :** n'écrire `notifiedAt` qu'après `success_count > 0`, ou supprimer le champ
et corriger le docstring.

### 3.6 — `round(jours)` peut valoir `0` → « plus de stock dans environ **0 jour(s)** » — prouvé

`functions/main.py` L115.

```
[6b] Sucre : 0.2 jour(s) estimés
  FAIL message sans '0 jour(s)' -> "Sucre : plus de stock dans environ 0 jour(s)"
  FAIL estimatedDaysLeft != 0   -> 0
```

**Fix :** `max(1, round(jours))` (ou `math.ceil`), pour la notification **et**
`estimatedDaysLeft`.

---

## 4. Problèmes majeurs (avant ou juste après merge)

### 4.1 — Le centre de notifications est une **maquette morte**

- `notification_center_screen.dart` : **4 cartes hardcodées** « Riz Royal 5kg… il y a
  1 h », bouton **« Tout lire » = `onPressed: () async {}`** (L27), aucun provider,
  **jamais routé** dans `app_router.dart`.
- `notification_providers.dart` L46 : le tap sur une notification pousse
  `AppRoutes.notificationsAlert` qui ouvre **`AlertPredictionScreen`**, alors que le
  commentaire dit *« redirige vers le centre de notifications »* →
  **commentaire/implémentation en contradiction**, et l'écran de notifications est
  injoignable.
- `alert_prediction_screen.dart` : **aucun AppBar, aucun bouton retour** → sur un
  kiosque (pas de bouton système Android), l'utilisateur est **bloqué** sur cet
  écran après avoir tapé une notification.
- Boutons `CardAlert` « Commander » / « Planifier » : `onPressed: () {}` (L88, L169,
  L251) → **actions factices**.

→ Soit on câble le centre de notifications aux vraies données, soit on le retire du
PR. Mais **il faut impérativement ajouter un retour** sur `AlertPredictionScreen`.

### 4.2 — Aucun test pour le feature

0 test Dart pour `alerts_predictions`, 0 test Python pour `main.py` (le harness
d'état utilisé pour cet audit prouve que des tests se seraient payés 5 bugs). Le
repo compte 80+ fichiers de test : **incohérent avec la culture du projet** et avec
la demande initiale de vérifications du PR.

### 4.3 — Sécurité Firestore : `firestore.rules` **absent du dépôt**

La collection **top-level `alerts`** est lue côté client avec
`where userId == uid && status == ACTIVE`. Il n'y a **aucun fichier `.rules` dans le
repo** : soit les règles sont définies dans la console (à documenter), soit la
lecture renverra `permission-denied` → écran en erreur. **À vérifier avant merge** —
c'est aussi un point de sécurité : une collection top-level partagée entre tous les
commerçants.

### 4.4 — iOS / macOS : notifications locales non fonctionnelles

`notification_remote_data_sources.dart` L71-72 : `InitializationSettings(android: ...)`
— **aucun `DarwinInitializationSettings`**, alors que le PR modifie
`macos/Flutter/GeneratedPluginRegistrant.swift` (le plugin est donc enregistré sur
macOS). Sur iOS/macOS : pas de permission demandée, pas d'affichage des
notifications en premier plan. **Seul Android est réellement testé.**

---

## 5. Problèmes moyens

| # | Problème | Réf. |
|---|---|---|
| 5.1 | **`enregistrerToken` utilise `update()`** → échec `NOT_FOUND` si le document `users/{uid}` n'existe pas encore au moment du login. Utiliser `set(..., merge: true)` | `notification_remote_data_sources.dart:50` |
| 5.2 | **`fcmTokens` croît sans borne** : `arrayUnion` jamais purgé, aucun nettoyage des tokens invalides retournés par `send_each_for_multicast` → quota/coût FCM qui se dégrade | idem + `main.py:212` |
| 5.3 | **Schedule en UTC** : `every day 06:00` = **09:00 à Madagascar** (UTC+3). Prévoir `timeZone` ou décaler à `every day 03:00` | `main.py:83` |
| 5.4 | **Scalabilité UC14** : `users` × `products` × **7 lectures séquentielles** par produit, sans batch. À ~50 users × 30 produits = **10 500 lectures** → risque de timeout (60 s par défaut) | `main.py:89-142` |
| 5.5 | **FCM sans `android.channel_id`** : en arrière-plan la notification part sur le canal *default* d'FCM, pas sur `kioskmind_alertes` → style/canal incohérent entre premier plan et arrière-plan | `main.py:212-217` |
| 5.6 | **`_typeFromString` renvoie `lowStock` pour tout type inconnu** → une alerte de type non reconnue s'affiche silencieusement comme « stock bas » | `alerts_model.dart:64` |
| 5.7 | **Listeners FCM jamais désabonnés** ; en cas de re-login avec un **autre uid**, un 2ᵉ jeu de listeners s'ajoute → token écrit sur l'ancien `userId` | `notification_providers.dart:61-73` |
| 5.8 | **`stockAtCreation` mis à jour à chaque déclenchement** alors que la notification n'est pas renvoyée → push dit « il ne reste que 8 » alors que l'alerte affiche 6 | `main.py:163` |
| 5.9 | **Aucune règle de réconciliation à la suppression d'un produit** : si un produit est supprimé, son alerte ACTIVE reste affichée indéfiniment | globale |
| 5.10 | Écran d'erreur affiché **brut** : `Erreur de chargement : Bad state: Aucun utilisateur connecté` | `alert_prediction_screen.dart:73` |

---

## 6. Mineurs / hygiène de PR

1. **`alert_repository_impl.dart` non formaté** (L29-30, ligne vide en trop) →
   `dart format` à lancer avant commit.
2. **Bruit de re-formatage** : `sales_dashboard_page.dart` = **-326 lignes
   majoritairement du `dart format`**, ce qui noie la vraie modification (la cloche
   → `context.push`) et créera des conflits. À isoler dans un commit `style` séparé.
3. Fichiers générés / hors-scope : `.metadata`, `devtools_options.yaml`,
   `windows/generated_plugins.cmake`, `macos/GeneratedPluginRegistrant.swift`,
   `.firebaserc`, `firebase.json` — à justifier ou à sortir du PR.
4. **`scripts/test_manual.py` ne reflète pas le schéma app** : écrit `price`
   (l'app utilise **`salePrice`**) et **omet `category`**
   (`product_model.dart` L9 `as String` non-null → crash si l'app lit ce produit de
   test). Incohérent pour un script censé reproduire la réalité.
5. **`CardAlert` = 3 blocs quasi identiques** (270 lignes, copiés-collés
   `urgent`/`prevision`/`conseil`) + `width: 359` hardcodé → **dérive du DRY**,
   risque de débordement sur écran étroit. Extraire un seul widget paramétré.
6. Indentation du `AndroidManifest.xml` cassée (L3-7, permissions sans indentation).
7. `AlertsModel.fromFirestore` : `data['type'] as String` non défensif + fallback
   `DateTime.now()` → tri instable si un champ manque (`alerts_model.dart:34,40`).
8. Pas de `region()` sur les fonctions → `us-central1` par défaut (latence depuis
   Madagascar).

---

## 7. Verdict

> **Non mergeable en l'état.** Le socle est **correct et bien architecturé** (clean
> architecture respectée, idempotence, anti-spam, i18n, batch de vente cohérent), mais
> **2 bloqueurs de déploiement** (`_kUseEmulator=true`, `requirements.txt` UTF-16) et
> **5 bugs de logique prouvés par exécution** doivent être corrigés.

### Plan de correction recommandé

**P0 — bloquant :**

1. `_kUseEmulator = false` (+ sortir l'IP hardcodée du code produit).
2. Ré-encoder `requirements.txt` en UTF-8.
3. `main.py` : branche `elif` → résoudre `NEGATIVE_STOCK` ; branche `else` → résoudre
   `PREDICTED_STOCKOUT`.
4. `max(1, round(jours))` pour la notification et `estimatedDaysLeft`.
5. `notifiedAt` écrit seulement si `success_count > 0` (ou supprimé + docstring
   corrigé).

**P1 — avant merge :**

6. Bouton retour sur `AlertPredictionScreen` (bloquage kiosque).
7. Décider : câbler `ScreenNotificationCenter` aux données **ou** le retirer du PR ;
   corriger le commentaire L44 de `notification_providers.dart`.
8. `set(merge: true)` pour `enregistrerToken` + purge des tokens invalides.
9. Ajouter des tests : au minimum le harness d'état UC13/UC14 en test Python + un
   test Dart du mapping `AlertsModel`.
10. Vérifier/commiter les `firestore.rules` pour la collection `alerts`.
11. `dart format` + découper le re-formatage de `sales_dashboard_page.dart` dans un
    commit `style`.

**P2 — suivi :**

12. iOS/macOS (`DarwinInitializationSettings`), fuseau du schedule, `channel_id` FCM,
    scaling d'UC14, assainissement de `CardAlert`.

---

## 8. Correctifs appliqués sur `feat/alert-prediction`

Branche créée depuis `origin/develop` puis merge de `origin/feature/alertPrediction`
(`c7fcb8d`), afin de conserver les derniers correctifs de `develop` (TTS, `formatCfa`).
Conflit sur `sales_dashboard_page.dart` résolu en faveur de `develop` : le PR portait
l'ancienne version dupliquée.

### P0 traité

| # | Correction | Commit |
|---|---|---|
| 1 | `_kUseEmulator` derrière `--dart-define=ALERTS_EMULATOR` (désactivé par défaut, plus de booléen à éditer) | `a69b025` |
| 2 | `functions/requirements.txt` ré-encodé en UTF-8 (était UTF-16LE BOM) | `16a4a2f` |
| 3 | `NEGATIVE_STOCK` résolu dans la branche `elif`, `PREDICTED_STOCKOUT` dans la branche `else` | `6cf5272` |
| 4 | `max(1, round(jours))` pour la notification et `estimatedDaysLeft` | `6cf5272` |
| 5 | `notifiedAt` écrit seulement si `_envoyer_notification` renvoie `True` (fonction désormais `-> bool`) | `6cf5272` |

### P1 traité

| # | Correction | Commit |
|---|---|---|
| 6 | AppBar avec retour ajoutée à `AlertPredictionScreen` | `1e7b136` |
| 7 | `ScreenNotificationCenter` câblé à `activeAlertsProvider` + routé (`/notification-center`) | `a2c85a2`, `f273adb` |
| 8 | `enregistrerToken` protégé en `try/catch` (un échec n'abandonne plus l'init FCM) | `6c19bab` |
| 9 | Tests : 19 tests Python de la machine à états UC13/UC14 + 8 tests Dart du mapping `AlertsModel` | `7b1b728` |
| 10 | `firestore.rules` **proposé** à la racine (non déployé, non référencé par `firebase.json`) | `b869cf8` |
| 11 | `dart format` sur tout le feature (`eb5d59d`) ; `macos/GeneratedPluginRegistrant` régénéré sans `firebase_storage` (`51a9241`) | |

### Fonctionnalités complétées

- `Alert.readAt` / `estLue`, `AlertsRepository.markAllAsRead` (batch Firestore).
- `AlertsModel.fromMap(id, data)` : testable, champs null-tolérants, `readAt` mappé.
- `alertsRepositoryProvider` extrait d'`activeAlertsProvider` (réutilisé par le centre).
- `CardAlert.onPressed` : boutons « Commander » et « Planifier » ouvrent le
  saisir-mouvement de stock en entrée (`RecordStockMovementPage`, type `inbound`),
  avec `SnackBar` si le produit n'est pas retrouvé.
- `alert_messages.dart` (`titreAlerte` / `messageAlerte`) : une seule source de
  libellés pour l'écran d'alertes et le centre de notifications.
- `core/formatting/relative_time.dart` (`formatRelativeTime`) : sans dépendance
  `intl` (déjà utilisée implicitement, évite d'ajouter un import).
- Centre de notifications : regroupement AUJOURD'HUI / PLUS TÔT, états
  loading/error/empty, bouton « Tout lire » → `markAllAsRead`, pastille `isUnread`.

### `firestore.rules` (à valider, PAS déployé)

Proposition non référencée par `firebase.json` : aucun risque de déploiement
accidentel. Pour la valider, cf. l'en-tête du fichier. Résumé :

- `users/{uid}` et ses sous-collections (`products`, `sales`, `dailyStats`,
  `stockMovements`) : accès strictement limité à `request.auth.uid == uid`.
- `alerts` (top-level, `{productId}_{type}`) : lecture réservée au propriétaire
  (`userId == auth.uid`) ; **création et suppression refusées au client** (Admin
  SDK des Cloud Functions uniquement) ; mise à jour limitée au champ `readAt`.
- Toute autre collection : refusé par défaut.

### Validations exécutées

- `dart format` : 18 fichiers, 4 reformattés.
- `flutter analyze` : **0 issue** (146 s).
- `flutter test test/alerts_predictions` : **8/8 OK**.
- `python3 functions/tests/test_alert_state_machine.py` : **19/19 OK**.
- Harness d'audit `/tmp/opencode/audit_harness/test_uc13_uc14.py` : **tous les
  checks passent** (14 checks sur `functions/main.py`).
- `flutter test test/products_stock/stock_overview_provider_test.dart` : **+6 OK**.

### Non exécutés / connus

- `flutter test test/routing test/sales` : **échec d'environnement**, pas de
  régression identifiée — `C:\` plein à 100 % (errno 112) ; le compilateur de tests
  Flutter écrit dans `C:\Users\Hp\AppData\Local\Temp`. À relancer après libération
  de `C:`.
- Non traité (P2, hors périmètre) : iOS/macOS, fuseau du `schedule`, `channel_id`
  FCM, scaling d'UC14, assainissement de `CardAlert`.
