import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';

Future<void> showToast(
  WidgetTester tester,
  String message,
  AppToastType type,
) async {
  final BuildContext context = tester.element(find.byType(Scaffold));
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(toastServiceProvider).show(message: message, type: type);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a toast with its message and icon', (tester) async {
    await pumpHost(tester);

    await showToast(tester, 'Compte créé', AppToastType.success);

    expect(find.text('Compte créé'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('applies the color matching the toast type', (tester) async {
    await pumpHost(tester);

    await showToast(tester, 'Erreur réseau', AppToastType.error);
    final Material errorMaterial = tester.widget(
      find.ancestor(
        of: find.text('Erreur réseau'),
        matching: find.byType(Material),
      ),
    );
    expect(errorMaterial.color, AppColors.error);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    await showToast(tester, 'Synchronisé', AppToastType.success);
    final Material successMaterial = tester.widget(
      find.ancestor(
        of: find.text('Synchronisé'),
        matching: find.byType(Material),
      ),
    );
    expect(successMaterial.color, AppColors.success);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    await showToast(tester, 'Session expirée', AppToastType.info);
    final Material infoMaterial = tester.widget(
      find.ancestor(
        of: find.text('Session expirée'),
        matching: find.byType(Material),
      ),
    );
    expect(infoMaterial.color, AppColors.info);
  });

  testWidgets('stacks multiple toasts', (tester) async {
    await pumpHost(tester);

    await showToast(tester, 'Premier', AppToastType.info);
    await showToast(tester, 'Deuxième', AppToastType.success);
    await showToast(tester, 'Troisième', AppToastType.error);

    expect(find.text('Premier'), findsOneWidget);
    expect(find.text('Deuxième'), findsOneWidget);
    expect(find.text('Troisième'), findsOneWidget);
  });

  testWidgets('auto dismisses a toast after the visible duration', (
    tester,
  ) async {
    await pumpHost(tester);

    await showToast(tester, 'Bientôt disparu', AppToastType.info);
    expect(find.text('Bientôt disparu'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bientôt disparu'), findsNothing);
  });

  testWidgets('leaves the underlying app interactive while toasts are shown', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return AppToastHost(child: child ?? const SizedBox.shrink());
          },
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Toucher'),
              ),
            ),
          ),
        ),
      ),
    );

    final BuildContext context = tester.element(find.byType(Scaffold));
    ProviderScope.containerOf(context, listen: false)
        .read(toastServiceProvider)
        .show(message: 'En cours', type: AppToastType.info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Toucher'));
    await tester.pump();

    expect(taps, 1);
  });
}
