import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_product_card.dart';

/// One card, at a width a merchant's phone really has.
///
/// [width] is a parameter because the specification calls out phones under 360
/// pixels by name, and a card that only ever gets tested at 390 is a card that has
/// not been tested where it breaks.
Future<void> pumpCard(
  WidgetTester tester,
  VoiceRecapLine line, {
  double width = 390,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: VoiceProductCard(line: line),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('a line with a price', () {
    const VoiceRecapLine soap = (
      name: 'Savon de ménage',
      qty: 2,
      unit: 'PIECE',
      unitPrice: 250,
    );

    testWidgets('shows the product, the arithmetic and the line total', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, soap);

      expect(find.text('Savon de ménage'), findsOneWidget);
      // The unit is written out, because "2 PIECE" is not something a merchant
      // reads, and the count agrees with the noun.
      expect(find.text('2 pièces × 250 F'), findsOneWidget);
      expect(find.text('500 FCFA'), findsOneWidget);
    });

    testWidgets('marks the product with its first letter', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, soap);

      // Not a photo: a voice session names products the merchant never saw on this
      // screen, so an empty box would read as a product that failed to load.
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('shows a fractional quantity as the merchant said it', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, (
        name: 'Riz parfumé',
        qty: 1.5,
        unit: 'KG',
        unitPrice: 5000,
      ));

      expect(find.text('1,5 kilogrammes × 5,000 F'), findsOneWidget);
      expect(find.text('7,500 FCFA'), findsOneWidget);
    });
  });

  group('a line without a price', () {
    testWidgets('shows the count and no figure', (WidgetTester tester) async {
      // A restock carries a purchase cost, not a selling price: printing one would
      // put a cost on a panel as though it were revenue.
      await pumpCard(tester, (
        name: 'Sucre',
        qty: 10,
        unit: 'SACHET',
        unitPrice: null,
      ));

      expect(find.text('10 sachets'), findsOneWidget);
      expect(find.textContaining('FCFA'), findsNothing);
    });

    testWidgets('shows a named product with no count', (
      WidgetTester tester,
    ) async {
      // A read moves nothing, so there is no quantity to print and no price to
      // apply: the card shows the product the question is about and nothing else.
      await pumpCard(tester, (
        name: 'Huile de palme',
        qty: 0,
        unit: null,
        unitPrice: null,
      ));

      expect(find.text('Huile de palme'), findsOneWidget);
      expect(find.textContaining('FCFA'), findsNothing);
    });
  });

  group('a long name', () {
    testWidgets('wraps instead of pushing the price off the card', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, (
        name: "Huile d'arachidekipara extravierge non désodorisée 5 litres",
        qty: 5,
        unit: 'LITRE',
        unitPrice: 2500,
      ), width: 320);

      expect(tester.takeException(), isNull);
      expect(find.text('12,500 FCFA'), findsOneWidget);
      // Capped at two lines: a name that runs the card's whole height would push the
      // price under the fold, and the price is what the merchant is checking.
      final Text name = tester.widget<Text>(
        find.text(
          "Huile d'arachidekipara extravierge non désodorisée 5 litres",
        ),
      );
      expect(name.maxLines, 2);
    });
  });

  group('a name that does not start with a letter', () {
    testWidgets('marks the product with the first letter it does find', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, (
        name: '  5 sacs de riz',
        qty: 5,
        unit: 'SAC',
        unitPrice: 5000,
      ));

      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('shows a dot rather than an empty box', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, (name: '5', qty: 5, unit: 'SAC', unitPrice: 5000));

      expect(find.text('·'), findsOneWidget);
    });
  });
}
