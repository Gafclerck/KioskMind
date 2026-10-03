import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/app_preferences.dart';
import 'core/storage/app_preferences_provider.dart';
import 'core/storage/shared_preferences_app_prefs.dart';
import 'firebase_options.dart';

/// Application entry point.
///
/// Keep this thin: it only wires dependencies and bootstraps services.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  final AppPreferences appPrefs = SharedPreferencesAppPrefs(sharedPrefs);
  final bool hasSeenOnboarding = await appPrefs.hasSeenOnboarding();

  runApp(
    KioskMindApp(
      overrides: [
        appPreferencesProvider.overrideWithValue(appPrefs),
        onboardingSeenProvider.overrideWith((ref) => hasSeenOnboarding),
      ],
    ),
  );
}
