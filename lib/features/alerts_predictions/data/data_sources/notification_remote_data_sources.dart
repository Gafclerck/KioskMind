import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class NotificationRemoteDataSources {
  Future<void> enregistrerToken(String userId, String token);
  Future<String?> obtenirToken();
}

class NotificationRemoteDataSourcesImpl
    implements NotificationRemoteDataSources {
  final FirebaseMessaging messaging;
  final FirebaseFirestore firestore;
  final FlutterLocalNotificationsPlugin local;
  NotificationRemoteDataSourcesImpl({
    required this.messaging,
    required this.local,
    required this.firestore,
  });

  @override
  Future<void> enregistrerToken(String userId, String token) async {
    await firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  @override
  Future<String?> obtenirToken() async {
    // Demande la permission à l'utilisateur
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    // Récupère le token unique de CET appareil précis
    final token = await messaging.getToken();
    return token;
  }
}
