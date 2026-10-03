import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

class SharedPreferencesAppPrefs implements AppPreferences {
  const SharedPreferencesAppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  @override
  Future<bool> hasSeenOnboarding() async {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() async {
    await _prefs.setBool(_keyHasSeenOnboarding, true);
  }
}
