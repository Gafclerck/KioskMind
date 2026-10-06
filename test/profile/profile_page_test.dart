import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';
import 'package:kiosk_mind/features/navigation/navigation_index_provider.dart';
import 'package:kiosk_mind/features/profile/domain/entities/user_profile.dart';
import 'package:kiosk_mind/features/profile/presentation/pages/profile_page.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/logout_provider.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/user_profile_provider.dart';

import 'fakes.dart';

final _kioskName = 'Kiosque du Sud';
final _market = 'Marché de Treichville';

Future<ProviderContainer> pumpProfile(
  WidgetTester tester, {
  DateTime? createdAt,
}) async {
  final FakeUserProfileRepository repository = FakeUserProfileRepository(
    initialProfile: UserProfile(
      fullName: 'David Koné',
      phone: '0700000000',
      countryCode: '+225',
      email: 'david@example.com',
      createdAt: createdAt,
      kioskName: _kioskName,
      marketLocation: _market,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => Stream<UserProfile?>.value(repository.profile),
        ),
        logoutProvider.overrideWith(() => FakeLogoutNotifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: const Scaffold(body: ProfilePage()),
      ),
    ),
  );

  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(ProfilePage)),
  );
  await container.read(userProfileProvider.future);
  await tester.pumpAndSettle();
  return container;
}

/// ProfilePage affiche ses destinations via `context.push`, on intercepte ces
/// routes pour observer la navigation sans monter l'écran cible.
Future<List<String>> pumpProfileWithRouter(
  WidgetTester tester, {
  DateTime? createdAt,
}) async {
  final FakeUserProfileRepository repository = FakeUserProfileRepository(
    initialProfile: UserProfile(
      fullName: 'David Koné',
      phone: '0700000000',
      countryCode: '+225',
      email: 'david@example.com',
      createdAt: createdAt,
      kioskName: _kioskName,
      marketLocation: _market,
    ),
  );

  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: ProfilePage()),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('EditProfilePage')),
      ),
      GoRoute(
        path: '/profile/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('SettingsPage')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => Stream<UserProfile?>.value(repository.profile),
        ),
        logoutProvider.overrideWith(() => FakeLogoutNotifier()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
  return <String>[];
}

void main() {
  testWidgets('leads with the app name on the left and the avatar', (
    tester,
  ) async {
    await pumpProfile(tester, createdAt: DateTime(2026, 10, 12));

    expect(find.text('KioskMind'), findsOneWidget);
    // Les informations personnelles ont quitté l'en-tête.
    expect(find.text('David Koné'), findsNothing);
    expect(find.text('+225 0700000000'), findsNothing);
  });

  testWidgets('shows only the member-since card with a French date', (
    tester,
  ) async {
    await pumpProfile(tester, createdAt: DateTime(2026, 10, 12));

    expect(find.text('Membre depuis'), findsOneWidget);
    expect(find.text('12 octobre 2026'), findsOneWidget);
    // Les compteurs de ventes et de produits ne sont plus affichés.
    expect(find.text('Ventes'), findsNothing);
    expect(find.text('Produits actifs'), findsNothing);
  });

  testWidgets('falls back to a dash when the account has no join date', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Membre depuis'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('offers exactly three tiles', (tester) async {
    await pumpProfile(tester, createdAt: DateTime(2026, 10, 12));

    expect(find.text('Mon kiosque et moi'), findsOneWidget);
    expect(find.text('Historique des ventes'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
    // La tuile « Modifier le profil » a fusionné dans « Mon kiosque et moi ».
    expect(find.text('Modifier le profil'), findsNothing);
    expect(find.text('Mon kiosque'), findsNothing);
    // Le résumé du kiosque reste lisible sur la tuile fusionnée.
    expect(find.text('$_kioskName · $_market'), findsOneWidget);
  });

  testWidgets('the kiosk tile opens the editable profile form', (tester) async {
    await pumpProfileWithRouter(tester, createdAt: DateTime(2026, 10, 12));

    await tester.tap(find.text('Mon kiosque et moi'));
    await tester.pumpAndSettle();

    expect(find.text('EditProfilePage'), findsOneWidget);
  });

  testWidgets('the settings tile opens the settings screen', (tester) async {
    await pumpProfileWithRouter(tester, createdAt: DateTime(2026, 10, 12));

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text('SettingsPage'), findsOneWidget);
  });

  testWidgets('the sales history tile switches to the sales tab', (
    tester,
  ) async {
    final ProviderContainer container = await pumpProfile(
      tester,
      createdAt: DateTime(2026, 10, 12),
    );

    await tester.tap(find.text('Historique des ventes'));
    await tester.pumpAndSettle();

    expect(container.read(navigationIndexProvider), 2);
  });

  testWidgets('keeps a confirmed sign-out at the bottom of the page', (
    tester,
  ) async {
    final FakeLogoutNotifier notifier = FakeLogoutNotifier();
    final FakeUserProfileRepository repository = FakeUserProfileRepository(
      initialProfile: UserProfile(
        fullName: 'David Koné',
        phone: '0700000000',
        countryCode: '+225',
        email: 'david@example.com',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(repository.profile),
          ),
          logoutProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (BuildContext context, Widget? child) {
            return AppToastHost(child: child ?? const SizedBox.shrink());
          },
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Se déconnecter'));
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.text('Se déconnecter ?'), findsOneWidget);
    expect(notifier.signOutCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(notifier.signOutCalls, 1);
    expect(find.text('Déconnexion réussie'), findsOneWidget);
  });
}
