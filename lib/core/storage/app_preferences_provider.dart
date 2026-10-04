import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError(
    'appPreferencesProvider must be overridden in ProviderScope',
  ),
);

/// Holds whether onboarding has been seen.
/// Initialized at app startup and updated when onboarding completes.
final onboardingSeenProvider = StateProvider<bool>((ref) => false);
