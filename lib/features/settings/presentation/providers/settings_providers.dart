import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggles de notifications, persistés localement.
final promosNotificationsProvider = StateProvider<bool>((ref) => true);

/// Alertes de stock : préférence locale + Firestore.
///
/// Les Functions (UC13/UC14) lisent `users/{uid}.stockAlertsEnabled` avant
/// d'envoyer un push. Une préférence gardée dans SharedPreferences seule ne
/// peut pas être lue depuis le serveur : d'où la synchronisation via
/// [synchroniserAlerteStock].
final stockAlertsProvider = StateProvider<bool>((ref) => true);

/// Champs que les Functions lisent pour décider d'envoyer un push.
/// Une clé absente vaut `true` (préférence par défaut, aucun produit
/// existant n'est privé de ses alertes après cette mise à jour).
Future<void> synchroniserAlerteStock(String uid, bool active) async {
  try {
    // update() et jamais set() : on ne doit pas fabriquer un users/{uid}
    // partiel, qui casserait les autres lecteurs du document.
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'stockAlertsEnabled': active,
    });
  } catch (erreur) {
    // ignore: avoid_print
    print('[notifications] Préférence alertes non synchronisée : $erreur');
  }
}
