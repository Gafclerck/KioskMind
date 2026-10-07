import 'package:firebase_messaging/firebase_messaging.dart';

abstract class NotificationRepository {
  Future<void> enregistrerToken(String userId, String token);
  Future<String?> obtenirToken();

  Future<void> initialiserPluginLocal({
    required void Function(Map<String, dynamic> data) onTapNotificationLocale,
  });

  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage();
  Future<void> afficherNotificationLocale(RemoteMessage message);
}
