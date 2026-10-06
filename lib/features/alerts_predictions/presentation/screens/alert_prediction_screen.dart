import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/providers/alerts_providers.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/widgets/card_alert.dart';

class AlertPredictionScreen extends ConsumerWidget {
  const AlertPredictionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const titleAppBar = "Prévisions & Alertes";
    final alertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      // La page est poussée par context.push : sans AppBar, aucun retour
      // possible sur un kiosque (pas de bouton système Android).
      appBar: AppBar(
        title: Text(
          titleAppBar,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: AppColors.primary, size: 20),
                    Text(
                      "Analyses Prédictives IA Actives",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 35.0),
                  child: SizedBox(
                    child: Text(
                      "KioskMind analyse votre historique et l'activité du quartier pour prédire vos besoins de stock.",
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                alertsAsync.when(
                  data: (alerts) {
                    if (alerts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text("Aucune alerte active pour le moment."),
                      );
                    }
                    return Column(
                      spacing: 10,
                      children: alerts.map(_buildCard).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text("Erreur de chargement : $error"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Alert alert) {
    final statut = switch (alert.type) {
      AlertType.lowStock || AlertType.negativeStock => StatutAlert.urgent,
      AlertType.predictedStockout => StatutAlert.prevision,
    };

    return CardAlert(
      statutAlert: statut,
      productNameWithStock: alert.productName,
      alertMessage: _messagePour(alert),
    );
  }

  String _messagePour(Alert alert) {
    switch (alert.type) {
      case AlertType.lowStock:
        return "Stock bas : il ne reste que ${alert.stockAtCreation} unité(s).";
      case AlertType.negativeStock:
        return "Stock négatif (${alert.stockAtCreation}) : vérifiez vos ventes récentes.";
      case AlertType.predictedStockout:
        final jours = alert.estimatedDaysLeft;
        return jours != null
            ? "Rupture prévue dans environ $jours jour(s)."
            : "Rupture de stock prévue prochainement.";
    }
  }
}
