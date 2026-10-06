import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class NotificationRemoteDataSources {
  Future<void> enregistrerToken(String userId, String token);
  Future<String?> obtenirToken();

  Future<void> initialiserPluginLocal({
    required void Function(Map<String, dynamic> data) onTapNotificationLocale,
  });

  Stream<String> get onTokenRefresh;

  /// Cas 1 : app ouverte au premier plan — rien ne s'affiche seul,
  /// il faut appeler afficherNotificationLocale() soi-même.
  Stream<RemoteMessage> get onMessage;

  /// Cas 2 : app en arrière-plan, l'utilisateur tape sur la notif système.
  Stream<RemoteMessage> get onMessageOpenedApp;

  /// Cas 3 : app était fermée, ouverte EN tapant sur la notif.
  Future<RemoteMessage?> getInitialMessage();

  Future<void> afficherNotificationLocale(RemoteMessage message);
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

  static const _canalAndroid = AndroidNotificationDetails(
    'kioskmind_alertes',
    'Alertes KioskMind',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  Future<void> enregistrerToken(String userId, String token) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (erreur) {
      // Pas de re-création du document : un users/{uid} partiel casserait
      // les autres lecteurs (name, language...). On laisse plutôt l'init
      // des notifications continuer — sans quoi AUCUN listener FCM ne
      // serait posé et l'app ne recevrait plus du tout de notification.
      // ignore: avoid_print
      print('[notifications] Enregistrement du token impossible : $erreur');
    }
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

  @override
  Future<void> initialiserPluginLocal({
    required void Function(Map<String, dynamic> data) onTapNotificationLocale,
  }) async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: initAndroid);
    await local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null) return;
        final data = Map<String, dynamic>.from(jsonDecode(payload));
        onTapNotificationLocale(data);
      },
    );
  }

  @override
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() => messaging.getInitialMessage();

  @override
  Future<void> afficherNotificationLocale(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(android: _canalAndroid),
      payload: jsonEncode(message.data),
    );
  }
}
