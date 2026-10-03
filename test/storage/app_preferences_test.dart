import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/storage/shared_preferences_app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'hasSeenOnboarding returns false when no preference is stored',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesAppPrefs appPrefs = SharedPreferencesAppPrefs(
        prefs,
      );

      expect(await appPrefs.hasSeenOnboarding(), isFalse);
    },
  );

  test(
    'markOnboardingSeen stores true and hasSeenOnboarding returns true',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesAppPrefs appPrefs = SharedPreferencesAppPrefs(
        prefs,
      );

      await appPrefs.markOnboardingSeen();

      expect(await appPrefs.hasSeenOnboarding(), isTrue);
    },
  );

  test(
    'hasSeenOnboarding returns true when preference was already true',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'has_seen_onboarding': true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesAppPrefs appPrefs = SharedPreferencesAppPrefs(
        prefs,
      );

      expect(await appPrefs.hasSeenOnboarding(), isTrue);
    },
  );
}
