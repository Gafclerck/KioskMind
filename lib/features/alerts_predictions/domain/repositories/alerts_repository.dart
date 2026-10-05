import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';

abstract class AlertsRepository {
  /// Flux des alertes ACTIVES de l'utilisateur, les plus récentes d'abord.
  Stream<List<Alert>> watchActiveAlerts();
}
