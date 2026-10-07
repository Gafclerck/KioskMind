/// Persistance locale des préférences de l'utilisateur.
abstract interface class AppPreferences {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();

  /// Mode d'affichage persistant : `system`, `light` ou `dark`.
  Future<String> getThemeMode();
  Future<void> setThemeMode(String mode);

  Future<bool> getPromosNotificationsEnabled();
  Future<void> setPromosNotificationsEnabled(bool enabled);

  Future<bool> getStockAlertsEnabled();
  Future<void> setStockAlertsEnabled(bool enabled);
}
