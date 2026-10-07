import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/storage/app_preferences_provider.dart';
import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/core/theme/theme_mode_provider.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/profile/presentation/pages/settings_page.dart';
import 'package:kiosk_mind/features/settings/presentation/providers/settings_providers.dart';
import 'package:kiosk_mind/features/settings/presentation/widgets/change_password_dialog.dart';

import '../auth/fakes.dart';
import '../core/fake_app_preferences.dart';

Future<void> pumpSettings(WidgetTester tester, FakeAppPreferences prefs) async {
  tester.view.physicalSize = const Size(800, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(prefs),
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the settings sections and the app version', (
    tester,
  ) async {
    await pumpSettings(tester, FakeAppPreferences());

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);
    expect(find.text('Changer le mot de passe'), findsOneWidget);
    expect(find.text('Préférences'), findsOneWidget);
    expect(find.text('Mode sombre'), findsOneWidget);
    expect(find.text('Offres et promotions'), findsOneWidget);
    expect(find.text('Alertes de stock'), findsOneWidget);
    expect(find.text('Langue'), findsNWidgets(2));
    expect(find.text('Données'), findsOneWidget);
    expect(find.text('Exporter mes ventes'), findsOneWidget);
    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Aide'), findsOneWidget);
    expect(find.text("Conditions d'Utilisation"), findsOneWidget);
    expect(find.text('Politique de Confidentialité'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('selecting the dark theme persists the preference', (
    tester,
  ) async {
    final FakeAppPreferences prefs = FakeAppPreferences();
    await pumpSettings(tester, prefs);

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(prefs.themeMode, 'dark');
  });

  testWidgets(
    'toggling promotions notifications updates state and preference',
    (tester) async {
      final FakeAppPreferences prefs = FakeAppPreferences();
      await pumpSettings(tester, prefs);

      await tester.tap(find.text('Offres et promotions'));
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      expect(container.read(promosNotificationsProvider), isFalse);
      expect(prefs.promosEnabled, isFalse);
      expect(find.textContaining('Préférence enregistrée'), findsOneWidget);
    },
  );

  testWidgets('toggling stock alerts updates state and preference', (
    tester,
  ) async {
    final FakeAppPreferences prefs = FakeAppPreferences();
    await pumpSettings(tester, prefs);

    await tester.tap(find.text('Alertes de stock'));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(stockAlertsProvider), isFalse);
    expect(prefs.stockAlertsEnabled, isFalse);
    expect(find.textContaining('Alertes de stock désactivées'), findsOneWidget);
  });

  testWidgets('tapping to change the password opens the dialog', (
    tester,
  ) async {
    await pumpSettings(tester, FakeAppPreferences());

    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordDialog), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordDialog), findsNothing);
  });
}
