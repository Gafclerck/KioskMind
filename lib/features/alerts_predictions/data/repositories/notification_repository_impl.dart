import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kiosk_mind/features/alerts_predictions/data/data_sources/notification_remote_data_sources.dart';
import 'package:kiosk_mind/features/alerts_predictions/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSources remoteDataSource;
  NotificationRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> enregistrerToken(String userId, String token) async {
    await remoteDataSource.enregistrerToken(userId, token);
  }

  @override
  Future<String?> obtenirToken() async {
    return await remoteDataSource.obtenirToken();
  }

  @override
  Future<void> initialiserPluginLocal({
    required void Function(Map<String, dynamic> data) onTapNotificationLocale,
  }) {
    return remoteDataSource.initialiserPluginLocal(
      onTapNotificationLocale: onTapNotificationLocale,
    );
  }

  @override
  Stream<String> get onTokenRefresh => remoteDataSource.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => remoteDataSource.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      remoteDataSource.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() =>
      remoteDataSource.getInitialMessage();

  @override
  Future<void> afficherNotificationLocale(RemoteMessage message) =>
      remoteDataSource.afficherNotificationLocale(message);
}
