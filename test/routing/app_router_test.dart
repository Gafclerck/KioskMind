import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/app.dart';
import 'package:kiosk_mind/core/storage/app_preferences.dart';
import 'package:kiosk_mind/core/storage/app_preferences_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/login_page.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:kiosk_mind/features/navigation/main_navigation_page.dart';
import 'package:kiosk_mind/features/onboarding/presentation/pages/onboarding_page.dart';

class FakeAppPreferences implements AppPreferences {
  bool seen = false;
  @override
  Future<bool> hasSeenOnboarding() async => seen;
  @override
  Future<void> markOnboardingSeen() async => seen = true;
}

void main() {
  testWidgets(
    'redirects to /onboarding on first launch when onboarding not seen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        KioskMindApp(
          overrides: [
            onboardingSeenProvider.overrideWith((ref) => false),
            authStateProvider.overrideWith(
              (ref) => Stream<String?>.value(null),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('Dictez vos ventes'), findsOneWidget);
    },
  );

  testWidgets(
    'redirects to /login when onboarding is seen but user is unauthenticated',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        KioskMindApp(
          overrides: [
            onboardingSeenProvider.overrideWith((ref) => true),
            authStateProvider.overrideWith(
              (ref) => Stream<String?>.value(null),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Bon retour !'), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );

  testWidgets(
    'redirects to /dashboard when onboarding seen and user is authenticated',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        KioskMindApp(
          overrides: [
            onboardingSeenProvider.overrideWith((ref) => true),
            authStateProvider.overrideWith(
              (ref) => Stream<String?>.value('user_123'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );

  testWidgets(
    'redirects automatically from /login to /dashboard when user signs in',
    (WidgetTester tester) async {
      final StreamController<String?> authController =
          StreamController<String?>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        KioskMindApp(
          overrides: [
            onboardingSeenProvider.overrideWith((ref) => true),
            authStateProvider.overrideWith((ref) => authController.stream),
          ],
        ),
      );

      // Initial state: not logged in
      authController.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);

      // User signs in
      authController.add('user_456');
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    },
  );

  testWidgets(
    'completing onboarding marks it seen and dynamically transitions to /login',
    (WidgetTester tester) async {
      final FakeAppPreferences fakePrefs = FakeAppPreferences();

      await tester.pumpWidget(
        KioskMindApp(
          overrides: [
            appPreferencesProvider.overrideWithValue(fakePrefs),
            onboardingSeenProvider.overrideWith((ref) => false),
            authStateProvider.overrideWith(
              (ref) => Stream<String?>.value(null),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);

      // Tap Passer to jump to the last slide
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      // Tap Commencer to complete onboarding
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(fakePrefs.seen, isTrue);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );
}
