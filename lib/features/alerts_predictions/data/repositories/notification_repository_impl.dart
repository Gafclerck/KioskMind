import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
}
