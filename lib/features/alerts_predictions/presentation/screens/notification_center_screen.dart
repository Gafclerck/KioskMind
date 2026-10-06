import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiosk_mind/core/formatting/relative_time.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/entities/alert.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/alert_messages.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/providers/alerts_providers.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/widgets/card_notification.dart';

/// Centre de notifications : les alertes réelles de l'utilisateur
/// (même source que [AlertPredictionScreen]), regroupées par jour.
///
/// Le bouton « Tout lire » marque les alertes affichées comme lues
/// (champ `readAt`, écrit côté Firestore).
class ScreenNotificationCenter extends ConsumerWidget {
  const ScreenNotificationCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.lightSurface,
            radius: 18,
            child: const Icon(Icons.arrow_back_ios, size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Centre de notifications",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => _toutLire(ref, alertsAsync.valueOrNull),
            child: Text(
              "Tout lire",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: alertsAsync.when(
          data: (alerts) => _corps(ref, alerts),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text("Erreur de chargement : $error")),
        ),
      ),
    );
  }

  Future<void> _toutLire(WidgetRef ref, List<Alert>? alerts) async {
    final nonLues =
        alerts
            ?.where((alerte) => !alerte.estLue)
            .map((alerte) => alerte.id)
            .toList() ??
        const <String>[];
    if (nonLues.isEmpty) return;

    final repository = await ref.read(alertsRepositoryProvider.future);
    await repository.markAllAsRead(nonLues);
  }

  Widget _corps(WidgetRef ref, List<Alert> alerts) {
    if (alerts.isEmpty) {
      return const Center(child: Text("Aucune notification pour le moment."));
    }

    final aujourdhui = <Alert>[];
    final plusTot = <Alert>[];
    final maintenant = DateTime.now();
    for (final alerte in alerts) {
      final memeJour =
          alerte.createdAt.year == maintenant.year &&
          alerte.createdAt.month == maintenant.month &&
          alerte.createdAt.day == maintenant.day;
      (memeJour ? aujourdhui : plusTot).add(alerte);
    }

    return ListView(
      children: [
        if (aujourdhui.isNotEmpty) ...[
          _SectionTitre("AUJOURD'HUI"),
          ...aujourdhui.map(_carte),
        ],
        if (plusTot.isNotEmpty) ...[
          _SectionTitre("PLUS TÔT"),
          ...plusTot.map(_carte),
        ],
      ],
    );
  }

  Widget _carte(Alert alerte) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CardNotification(
      notificationTitle: titreAlerte(alerte),
      message: messageAlerte(alerte),
      time: formatRelativeTime(alerte.createdAt),
      isUnread: !alerte.estLue,
    ),
  );
}

class _SectionTitre extends StatelessWidget {
  const _SectionTitre(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}
