import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggles de notifications, persistés localement.
///
/// La remontée des notifications natives (Firebase Messaging) n'étant pas
/// encore câblée, ces toggles conditionnent des préférences locales et
/// serviront de base à la future configuration Push.
final promosNotificationsProvider = StateProvider<bool>((ref) => true);

final stockAlertsProvider = StateProvider<bool>((ref) => true);
