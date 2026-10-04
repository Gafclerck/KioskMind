import 'package:flutter/material.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/widgets/card_alert.dart';

class AlertPredictionScreen extends StatelessWidget {
  const AlertPredictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const titleAppBar = "Prévisions & Alertes";
    return Scaffold(
      // appBar: AppBar(title: const Text(titleAppBar)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleAppBar,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
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
                CardAlert(
                  statutAlert: StatutAlert.urgent,
                  productNameWithStock: "Sacs de Riz 5kg",
                  alertMessage: "Rupture prévue demain. 2 sacs restants.",
                ),
                CardAlert(
                  statutAlert: StatutAlert.prevision,
                  productNameWithStock: "Sacs de Riz 5kg",
                  alertMessage: "Rupture prévue demain. 2 sacs restants.",
                ),
                CardAlert(
                  statutAlert: StatutAlert.conseil,
                  productNameWithStock: "Sacs de Riz 5kg",
                  alertMessage:
                      "Livraison hebdomadaire recommandée d’ici Vendredi.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
