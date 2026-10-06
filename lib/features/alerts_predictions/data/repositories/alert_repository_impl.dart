import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/models/alerts_model.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/repositories/alerts_repository.dart';

class AlertsRepositoryImpl implements AlertsRepository {
  final FirebaseFirestore firestore;
  final String userId;

  AlertsRepositoryImpl({required this.firestore, required this.userId});

  @override
  Stream<List<Alert>> watchActiveAlerts() {
    return firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'ACTIVE')
        // orderBy retiré : évite l'index composite — tri fait côté Dart.
        .snapshots()
        .map((snapshot) {
          final alerts = snapshot.docs
              .map((doc) => AlertsModel.fromFirestore(doc).toEntity())
              .toList();
          // Tri décroissant par date de création (les plus récentes d'abord).
          alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return alerts;
        });
  }

  @override
  Future<void> markAllAsRead(List<String> alertIds) async {
    if (alertIds.isEmpty) return;
    final batch = firestore.batch();
    final lue = Timestamp.fromDate(DateTime.now().toUtc());
    for (final id in alertIds) {
      batch.update(firestore.collection('alerts').doc(id), {'readAt': lue});
    }
    await batch.commit();
  }
}
