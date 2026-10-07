import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';

import 'package:kiosk_mind/app.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/core/theme/app_typography.dart';

double _contrastRatio(Color foreground, Color background) {
  final double foregroundLuminance = foreground.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppColors', () {
    test('keeps the mandated brand tokens untouched', () {
      expect(AppColors.primary, const Color(0xFF156C61));
      expect(AppColors.secondary, const Color(0xFFE9973E));
      expect(AppColors.error, const Color(0xFFE55B48));
      expect(AppColors.success, const Color(0xFF1A9E75));
      expect(AppColors.lightBackground, const Color(0xFFFAF9F5));
      expect(AppColors.lightSurface, const Color(0xFFFFFFFF));
      expect(AppColors.darkBackground, const Color(0xFF12181A));
      expect(AppColors.darkSurface, const Color(0xFF1E2628));
    });

    test('keeps the mandated text tokens untouched', () {
      expect(AppColors.textPrimaryLight, const Color(0xFF1E292B));
      expect(AppColors.textSecondaryLight, const Color(0xFF6B7A7D));
      expect(AppColors.textPrimaryDark, const Color(0xFFF5F7F8));
      expect(AppColors.textSecondaryDark, const Color(0xFFA0AEC0));
    });
  });

  group('AppTheme', () {
    test('light theme paints the light background and surface', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        AppColors.lightBackground,
      );
      expect(
        AppTheme.lightTheme.colorScheme.surface,
        AppColors.lightBackground,
      );
      expect(AppTheme.lightTheme.cardTheme.color, AppColors.lightSurface);
    });

    test('dark theme paints the dark background and surface', () {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        AppColors.darkBackground,
      );
      expect(AppTheme.darkTheme.colorScheme.surface, AppColors.darkBackground);
      expect(AppTheme.darkTheme.cardTheme.color, AppColors.darkSurface);
    });

    test('dark theme keeps the brand accents vivid', () {
      final ColorScheme scheme = AppTheme.darkTheme.colorScheme;
      expect(scheme.primary, AppColors.primaryDark);
      expect(scheme.secondary, AppColors.secondary);
      expect(
        _contrastRatio(scheme.primary, AppColors.darkBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.secondary, AppColors.darkBackground),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('cards are rounded to 16 pixels', () {
      final ShapeBorder? shape = AppTheme.lightTheme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final BorderRadius radius =
          (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
      expect(radius.topLeft.x, 16);
    });

    test('input fields are filled and rounded to 12 pixels', () {
      final InputDecorationThemeData decoration =
          AppTheme.lightTheme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      final OutlineInputBorder border =
          decoration.border! as OutlineInputBorder;
      expect(border.borderRadius.topLeft.x, 12);
      expect(decoration.focusedBorder, isA<OutlineInputBorder>());
      expect(decoration.errorBorder, isA<OutlineInputBorder>());
    });

    test('every text style uses Plus Jakarta Sans', () {
      for (final TextStyle? style in <TextStyle?>[
        ..._allStyles(AppTheme.lightTheme.textTheme),
        ..._allStyles(AppTheme.darkTheme.textTheme),
      ]) {
        expect(style?.fontFamily, AppTypography.fontFamily);
      }
    });

    test('light scheme is readable on its own surfaces', () {
      final ColorScheme scheme = AppTheme.lightTheme.colorScheme;
      final List<(Color, Color)> pairs = <(Color, Color)>[
        (scheme.onSurface, scheme.surface),
        (scheme.onSurface, scheme.surfaceContainer),
        (scheme.onSurface, scheme.surfaceContainerHighest),
        (scheme.primary, scheme.surface),
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onErrorContainer, scheme.errorContainer),
      ];
      for (final (Color foreground, Color background) in pairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    });

    test('dark scheme is readable on its own surfaces', () {
      final ColorScheme scheme = AppTheme.darkTheme.colorScheme;
      final List<(Color, Color)> pairs = <(Color, Color)>[
        (scheme.onSurface, scheme.surface),
        (scheme.onSurface, scheme.surfaceContainer),
        (scheme.onSurface, scheme.surfaceContainerHighest),
        (scheme.onSurfaceVariant, scheme.surface),
        (scheme.primary, scheme.surface),
        (scheme.primary, scheme.surfaceContainer),
        (scheme.secondary, scheme.surface),
        (scheme.error, scheme.surface),
        (scheme.onPrimary, scheme.primary),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onErrorContainer, scheme.errorContainer),
      ];
      for (final (Color foreground, Color background) in pairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    });
  });

  group('KioskMindApp', () {
    testWidgets('exposes both themes and follows the system mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith((ref) => Stream.value(<Product>[])),
          ],
          child: const KioskMindApp(),
        ),
      );
      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme?.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(app.darkTheme?.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    testWidgets('renders themed components in both brightnesses', (
      WidgetTester tester,
    ) async {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.lightTheme,
        AppTheme.darkTheme,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(title: const Text('KioskMind')),
              body: const Card(child: TextField()),
              bottomNavigationBar: BottomNavigationBar(
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined),
                    label: 'Accueil',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: 'Stock',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    label: 'Réglages',
                  ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Accueil'), findsOneWidget);
      }
    });
  });
}

List<TextStyle?> _allStyles(TextTheme textTheme) {
  return <TextStyle?>[
    textTheme.displayLarge,
    textTheme.displayMedium,
    textTheme.displaySmall,
    textTheme.headlineLarge,
    textTheme.headlineMedium,
    textTheme.headlineSmall,
    textTheme.titleLarge,
    textTheme.titleMedium,
    textTheme.titleSmall,
    textTheme.bodyLarge,
    textTheme.bodyMedium,
    textTheme.bodySmall,
    textTheme.labelLarge,
    textTheme.labelMedium,
    textTheme.labelSmall,
  ];
}
