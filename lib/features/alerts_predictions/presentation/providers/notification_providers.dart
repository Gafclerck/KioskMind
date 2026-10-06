import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/data_sources/notification_remote_data_sources.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/repositories/notification_repository_impl.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/repositories/notification_repository.dart';
import 'package:kiosk_mind/features/settings/presentation/providers/settings_providers.dart';

import '../../../../routing/app_router.dart';
import '../../../../routing/app_routes.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final notificationRemoteDataSourcesProvider =
    Provider<NotificationRemoteDataSources>((ref) {
      return NotificationRemoteDataSourcesImpl(
        messaging: ref.watch(firebaseMessagingProvider),
        local: FlutterLocalNotificationsPlugin(),
        firestore: FirebaseFirestore.instance,
      );
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDataSourcesProvider),
  );
});

/// Orchestration complète : à appeler une fois, juste après la connexion.
///   ref.read(initialiserNotificationsProvider(userId));
final initialiserNotificationsProvider = FutureProvider.family<void, String>((
  ref,
  userId,
) async {
  final repository = ref.watch(notificationRepositoryProvider);
  final goRouter = ref.watch(appRouterProvider);

  /// Reçoit TOUTES les données de la notif, peu importe lequel des
  /// 3 cas l'a déclenché.
  ///
  /// payload serveur : `type`, `productId`, `userId` (functions/main.py).
  void traiterDonneesNotification(Map<String, dynamic> data) {
    final Object? productId = data['productId'];
    if (productId is String && productId.isNotEmpty) {
      goRouter.push(AppRoutes.productDetail.replaceFirst(':id', productId));
      return;
    }
    // Payload sans produit ciblé : on retombe sur la liste des alertes.
    goRouter.push(AppRoutes.notificationsAlert);
  }

  // Plugin local (gère le tap sur une notif qu'ON a affichée nous-mêmes)
  await repository.initialiserPluginLocal(
    onTapNotificationLocale: traiterDonneesNotification,
  );

  // Token initial
  final token = await repository.obtenirToken();
  if (token != null) {
    await repository.enregistrerToken(userId, token);
  }

  // Renouvellement de token
  repository.onTokenRefresh.listen((nouveauToken) {
    repository.enregistrerToken(userId, nouveauToken);
  });

  // Cas 1 : premier plan — rien ne s'affiche automatiquement.
  // Le toggle « Alertes de stock » masque l'affichage local ; côté
  // arrière-plan c'est le serveur qui ne part pas (voir main.py).
  repository.onMessage.listen((message) {
    if (!ref.read(stockAlertsProvider)) return;
    repository.afficherNotificationLocale(message);
  });

  // Cas 2 : arrière-plan, tap sur la notif système
  repository.onMessageOpenedApp.listen((message) {
    traiterDonneesNotification(message.data);
  });

  // Cas 3 : app était fermée, ouverte en tapant sur la notif
  final messageInitial = await repository.getInitialMessage();
  if (messageInitial != null) {
    traiterDonneesNotification(messageInitial.data);
  }
});
