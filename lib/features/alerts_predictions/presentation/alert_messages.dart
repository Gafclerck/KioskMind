import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';

/// Libellés des alertes, partagés par l'écran de prévisions et le centre
/// de notifications : les deux vues doivent raconter la même chose, avec
/// des mots différents si besoin — mais jamais un sens différent.
String titreAlerte(Alert alerte) => switch (alerte.type) {
  AlertType.lowStock || AlertType.negativeStock => 'Alerte stock',
  AlertType.predictedStockout => 'Prédiction',
};

/// Message principal d'une alerte.
String messageAlerte(Alert alerte) => switch (alerte.type) {
  AlertType.lowStock =>
    'Stock bas : il ne reste que ${alerte.stockAtCreation} unité(s).',
  AlertType.negativeStock =>
    'Stock négatif (${alerte.stockAtCreation}) : vérifiez vos ventes récentes.',
  AlertType.predictedStockout =>
    alerte.estimatedDaysLeft != null
        ? 'Rupture prévue dans environ ${alerte.estimatedDaysLeft} jour(s).'
        : 'Rupture de stock prévue prochainement.',
};
