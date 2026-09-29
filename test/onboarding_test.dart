import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:kiosk_mind/features/onboarding/presentation/pages/onboarding_page.dart';

const Duration _autoAdvance = Duration(seconds: 5);

Future<void> pumpOnboarding(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: OnboardingPage())),
  );
  await tester.pump();
}

int currentIndex(WidgetTester tester) {
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(OnboardingPage)),
  );
  return container.read(onboardingControllerProvider).currentIndex;
}

void main() {
  testWidgets('renders the first slide with navigation controls and dots', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.text('Dictez vos ventes'), findsOneWidget);
    expect(
      find.text(
        'Enregistrez vos ventes en parlant naturellement, même quand vos mains sont occupées.',
      ),
      findsOneWidget,
    );
    expect(find.text('Passer'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Retour'), findsNothing);
    expect(find.text('Commencer'), findsNothing);
    for (int i = 0; i < OnboardingState.pageCount; i++) {
      expect(find.byKey(ValueKey<String>('onboarding_dot_$i')), findsOneWidget);
    }
    expect(currentIndex(tester), 0);
  });

  testWidgets('auto-advances every five seconds and stops on the last slide', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.pump(_autoAdvance);
    await tester.pumpAndSettle();
    expect(find.text('Suivez votre stock'), findsOneWidget);
    expect(currentIndex(tester), 1);

    await tester.pump(_autoAdvance);
    await tester.pumpAndSettle();
    expect(find.text('Anticipez les ruptures'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Commencer'), findsOneWidget);
    expect(currentIndex(tester), 2);

    await tester.pump(_autoAdvance);
    await tester.pumpAndSettle();
    expect(find.text('Anticipez les ruptures'), findsOneWidget);
    expect(currentIndex(tester), 2);
  });

  testWidgets('navigates through the slides with Suivant and Retour', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Suivez votre stock'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
    expect(currentIndex(tester), 1);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Dictez vos ventes'), findsOneWidget);
    expect(currentIndex(tester), 0);
  });

  testWidgets('Passer jumps straight to the last slide', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(find.text('Anticipez les ruptures'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
    expect(currentIndex(tester), 2);
  });

  testWidgets('swiping advances the slides and updates the indicator', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Suivez votre stock'), findsOneWidget);
    expect(currentIndex(tester), 1);
  });

  testWidgets('Commencer replaces onboarding with the login page', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
