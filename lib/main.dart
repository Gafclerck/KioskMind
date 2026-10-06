import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/app_preferences.dart';
import 'core/storage/app_preferences_provider.dart';
import 'core/storage/shared_preferences_app_prefs.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'firebase_options.dart';

/// Doit être une fonction top-level (hors de toute classe) : appelée
/// par le système même quand l'app n'est pas vraiment démarrée.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Application entry point.
///
/// Keep this thin: it only wires dependencies and bootstraps services.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  final AppPreferences appPrefs = SharedPreferencesAppPrefs(sharedPrefs);
  final bool hasSeenOnboarding = await appPrefs.hasSeenOnboarding();
  final ThemeMode savedThemeMode = _parseThemeMode(
    await appPrefs.getThemeMode(),
  );
  final bool promosEnabled = await appPrefs.getPromosNotificationsEnabled();
  final bool stockAlertsEnabled = await appPrefs.getStockAlertsEnabled();

  runApp(
    KioskMindApp(
      overrides: [
        appPreferencesProvider.overrideWithValue(appPrefs),
        onboardingSeenProvider.overrideWith((ref) => hasSeenOnboarding),
        themeModeProvider.overrideWith((ref) => savedThemeMode),
        promosNotificationsProvider.overrideWith((ref) => promosEnabled),
        stockAlertsProvider.overrideWith((ref) => stockAlertsEnabled),
      ],
    ),
  );
}

ThemeMode _parseThemeMode(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
