import 'package:kiosk_mind/core/storage/app_preferences.dart';

class FakeAppPreferences implements AppPreferences {
  bool _seen = false;
  String _themeMode = 'system';
  bool _promosEnabled = true;
  bool _stockAlertsEnabled = true;

  bool get seen => _seen;
  String get themeMode => _themeMode;
  bool get promosEnabled => _promosEnabled;
  bool get stockAlertsEnabled => _stockAlertsEnabled;

  @override
  Future<bool> hasSeenOnboarding() async => _seen;

  @override
  Future<void> markOnboardingSeen() async => _seen = true;

  @override
  Future<String> getThemeMode() async => _themeMode;

  @override
  Future<void> setThemeMode(String mode) async => _themeMode = mode;

  @override
  Future<bool> getPromosNotificationsEnabled() async => _promosEnabled;

  @override
  Future<void> setPromosNotificationsEnabled(bool enabled) async =>
      _promosEnabled = enabled;

  @override
  Future<bool> getStockAlertsEnabled() async => _stockAlertsEnabled;

  @override
  Future<void> setStockAlertsEnabled(bool enabled) async =>
      _stockAlertsEnabled = enabled;
}
