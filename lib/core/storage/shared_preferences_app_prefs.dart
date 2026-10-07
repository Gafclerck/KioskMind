import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

class SharedPreferencesAppPrefs implements AppPreferences {
  const SharedPreferencesAppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyPromosNotifications = 'notifications_promos';
  static const String _keyStockAlerts = 'notifications_stock';

  @override
  Future<bool> hasSeenOnboarding() async {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() async {
    await _prefs.setBool(_keyHasSeenOnboarding, true);
  }

  @override
  Future<String> getThemeMode() async {
    return _prefs.getString(_keyThemeMode) ?? 'system';
  }

  @override
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  @override
  Future<bool> getPromosNotificationsEnabled() async {
    return _prefs.getBool(_keyPromosNotifications) ?? true;
  }

  @override
  Future<void> setPromosNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyPromosNotifications, enabled);
  }

  @override
  Future<bool> getStockAlertsEnabled() async {
    return _prefs.getBool(_keyStockAlerts) ?? true;
  }

  @override
  Future<void> setStockAlertsEnabled(bool enabled) async {
    await _prefs.setBool(_keyStockAlerts, enabled);
  }
}
