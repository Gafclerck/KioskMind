abstract interface class AppPreferences {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();
}
