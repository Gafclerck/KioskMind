import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/app.dart';
import 'package:kiosk_mind/core/storage/app_preferences_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/pages/login_page.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:kiosk_mind/features/navigation/main_navigation_page.dart';
import 'package:kiosk_mind/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/add_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/sales_repository.dart';
import 'package:kiosk_mind/features/sales/presentation/pages/create_sale_page.dart';
import 'package:kiosk_mind/features/sales/presentation/providers/sales_provider.dart';

import '../core/fake_app_preferences.dart';

final class _FakeSalesRepo implements SalesRepository {
  @override
  Future<Sale> recordSale(Sale sale) async => sale;

  @override
  Future<Sale> updateSale(Sale sale) async => sale;

  @override
  Future<Sale> cancelSale(String saleId) async => Sale(
    id: saleId,
    dateTime: DateTime(2026, 3, 1),
    createdAt: DateTime(2026, 3, 1),
    total: 0,
    items: const <SaleItem>[],
    source: 'TEST',
    status: 'CANCELLED',
  );

  @override
  Future<List<Sale>> getSalesHistory() async => const <Sale>[];

  @override
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async => const <Sale>[];

  @override
  Stream<List<Sale>> watchSalesHistory() {
    return Stream.value(const <Sale>[]);
  }
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
            productsProvider.overrideWith((ref) => Stream.value(<Product>[])),
            salesRepositoryProvider.overrideWithValue(_FakeSalesRepo()),
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
            productsProvider.overrideWith((ref) => Stream.value(<Product>[])),
            salesRepositoryProvider.overrideWithValue(_FakeSalesRepo()),
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

  testWidgets('dashboard quick action Nouvelle vente opens CreateSalePage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      KioskMindApp(
        overrides: [
          onboardingSeenProvider.overrideWith((ref) => true),
          authStateProvider.overrideWith(
            (ref) => Stream<String?>.value('user_123'),
          ),
          productsProvider.overrideWith((ref) => Stream.value(<Product>[])),
          salesRepositoryProvider.overrideWithValue(_FakeSalesRepo()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSalePage), findsOneWidget);
  });

  testWidgets('dashboard quick action Ajouter produit opens AddProductPage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      KioskMindApp(
        overrides: [
          onboardingSeenProvider.overrideWith((ref) => true),
          authStateProvider.overrideWith(
            (ref) => Stream<String?>.value('user_123'),
          ),
          productsProvider.overrideWith((ref) => Stream.value(<Product>[])),
          salesRepositoryProvider.overrideWithValue(_FakeSalesRepo()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AddProductPage), findsOneWidget);
  });
}
