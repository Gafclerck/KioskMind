import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/repositories/alert_repository_impl.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/repositories/alerts_repository.dart';
import 'package:kiosk_mind/firebase_options.dart';

// ── Test local avec l'émulateur (alerts_predictions uniquement) ──────
// Activé uniquement au lancement : flutter run --dart-define=ALERTS_EMULATOR=true
// Désactivé par défaut : impossible de livrer une build qui lit
// l'émulateur en production.
// Rien d'autre dans l'app n'est affecté : on utilise une SECONDE
// instance Firebase, nommée, totalement indépendante de
// FirebaseFirestore.instance (celle que product_repository_impl.dart
// et le reste de l'app continuent d'utiliser normalement).
const bool _kUseEmulator = bool.fromEnvironment('ALERTS_EMULATOR');

// Doit correspondre à l'UID du document "users/{...}" créé par
// scripts/test_manual_v2.py — pas besoin de l'Auth emulator, puisqu'on
// n'a pas besoin d'une vraie session pour ce test local.
const String _kTestUserId = 'test_alerts_uid';

/// Crée (ou réutilise) une app Firebase secondaire, dédiée à ce test.
Future<FirebaseApp> _emulatorApp() async {
  try {
    return Firebase.app('alertsEmulatorApp');
  } on FirebaseException {
    return Firebase.initializeApp(
      name: 'alertsEmulatorApp',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<FirebaseFirestore> _emulatorFirestore() async {
  final app = await _emulatorApp();
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.useFirestoreEmulator('10.0.2.2', 8080);
  return firestore;
}
// ───────────────────────────────────────────────────────────────────

/// Instance Firestore + uid à utiliser pour les alertes (émulateur ou
/// production). Partagé par tous les providers du feature pour éviter
/// de dupliquer la logique.
///
/// - émulateur : instance secondaire isolée, uid fixe `test_alerts_uid`
/// - production : instance principale, uid de l'utilisateur connecté
final alertsRepositoryProvider = FutureProvider<AlertsRepository>((ref) async {
  final String firestoreInstanceDescription;
  final FirebaseFirestore firestore;
  final String uid;

  if (_kUseEmulator) {
    firestore = await _emulatorFirestore();
    uid = _kTestUserId;
    firestoreInstanceDescription = 'émulateur local';
  } else {
    firestore = FirebaseFirestore.instance;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) throw StateError('Aucun utilisateur connecté');
    uid = currentUid;
    firestoreInstanceDescription = 'production';
  }

  // ignore: avoid_print
  print('[alerts] Lecture depuis $firestoreInstanceDescription, uid=$uid');

  return AlertsRepositoryImpl(firestore: firestore, userId: uid);
});

/// StreamProvider "async*" : peut attendre (await) avant de produire
/// le flux réel — utile ici pour résoudre l'instance Firestore à
/// utiliser avant de lancer la vraie requête.
final activeAlertsProvider = StreamProvider<List<Alert>>((ref) async* {
  final repository = await ref.watch(alertsRepositoryProvider.future);
  yield* repository.watchActiveAlerts();
});
