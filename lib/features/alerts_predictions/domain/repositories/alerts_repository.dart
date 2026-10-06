import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';

abstract class AlertsRepository {
  /// Flux des alertes ACTIVES de l'utilisateur, les plus récentes d'abord.
  Stream<List<Alert>> watchActiveAlerts();

  /// Marque ces alertes comme lues (centre de notifications).
  /// Ne fait rien si la liste est vide.
  Future<void> markAllAsRead(List<String> alertIds);
}
