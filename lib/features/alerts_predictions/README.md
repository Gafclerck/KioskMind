# Feature : Alertes & Prédictions (Epic 4)

Implémente **UC13** (notification de rupture, seuil bas) et **UC14**
(prédiction de rupture, exécution quotidienne), avec notifications
push via Firebase Cloud Messaging — y compris app fermée.

## Architecture

```
alerts_predictions/
  data/
    data_sources/notification_remote_data_sources.dart   # FCM + plugin local
    models/alerts_model.dart                               # mapping Firestore
    repositories/notification_repository_impl.dart
    repositories/alert_repository_impl.dart
  domain/
    entities/alert.dart
    repositories/notification_repository.dart
    repositories/alerts_repository.dart
  presentation/
    providers/notification_providers.dart   # token, listeners, navigation
    providers/alerts_providers.dart         # lecture de la collection "alerts"
    screens/alert_prediction_screen.dart
    screens/notification_center_screen.dart
    widgets/card_alert.dart
    widgets/card_notification.dart
```

Logique serveur (Cloud Functions) : `functions/main.py`
Script de test local : `scripts/test_manual.py`

## Prérequis

- Node.js 18+ (pour l'émulateur Firebase)
- Python 3.10+
- Firebase CLI : `npm install -g firebase-tools`
- Un compte Google avec accès au projet Firebase `kiosk-mind`

## Installation

```bash
firebase login

cd functions
pip install -r requirements.txt --break-system-packages
cd ..

pip install google-cloud-firestore --break-system-packages
```

Si les émulateurs n'ont encore jamais été configurés sur ta machine :

```bash
firebase init emulators
# Cocher : Functions Emulator, Firestore Emulator, Pub/Sub Emulator
# Garder les ports par défaut (Functions: 5001, Firestore: 8080, Pub/Sub: 8085)
# Activer l'Emulator UI (port 4000)
```

## Lancer les émulateurs

```bash
firebase emulators:start
```

Interface web : http://127.0.0.1:4000

## Tester UC13 et UC14 en local

Dans un **second terminal**, une fois les émulateurs lancés :

```bash
python scripts/test_manual.py
```

Ce script :
1. Crée un user de test (`users/test_alerts_uid`)
2. Crée un produit "Riz" avec un historique de ventes (`dailyStats`)
3. Simule une vente qui fait passer le stock sous le seuil → déclenche `verifier_stock` (UC13)
4. Simule un réapprovisionnement → vérifie la résolution des alertes
5. Prépare un produit "Huile" pour tester UC14

Pour déclencher **UC14** manuellement (les fonctions planifiées ne se
lancent jamais seules dans l'émulateur) :

```bash
firebase functions:shell
predictions_quotidiennes()
```

## Afficher les alertes dans l'app Flutter (`AlertPredictionScreen`)

Dans `alerts_providers.dart`, la constante en tête de fichier contrôle
la source de données :

```dart
const bool _kUseEmulator = true;   // local (émulateur)
const bool _kUseEmulator = false;  // production (vraie base Firebase)
```

Quand `_kUseEmulator = true`, l'app lit une **instance Firestore
secondaire**, isolée du reste de l'app (qui continue de parler à la
vraie base normalement) — aucun autre fichier n'est affecté.

L'UID utilisé en mode émulateur est fixe (`test_alerts_uid`), pas
besoin d'une vraie connexion ni de l'Auth emulator.

**⚠️ Remettre `_kUseEmulator = false` avant de committer pour de bon.**

## Tester l'envoi réel de notifications (FCM)

FCM n'est **pas émulé** — tout appel à `messaging.send_each_for_multicast()`
contacte réellement les serveurs Google, même depuis l'émulateur local.

1. Récupérer un vrai token FCM depuis un appareil physique (émulateur/
   simulateur non supportés pour les push réels)
2. Le coller dans `fcmTokens` du user de test (`test_manual.py`)
3. Lancer le scénario — la notification doit arriver sur le téléphone,
   y compris app fermée


## Déploiement en production

Nécessite le plan Blaze activé sur le projet Firebase (géré par le
responsable du projet) :

```bash
firebase deploy --only functions
```