import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_results_panel.dart';

/// The panel on its own, in the state a test needs it in.
///
/// Mounted without the panel above it so the rules below are checked here rather
/// than inferred from a whole session: what decides the heading, what decides the
/// total, and what decides whether there is a heading at all.
Future<void> pumpPanel(
  WidgetTester tester, {
  List<VoiceRecapLine> lines = const <VoiceRecapLine>[],
  bool isRecorded = false,
  double? total,
  String? summary,
  Widget? child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: VoiceResultsPanel(
            lines: lines,
            isRecorded: isRecorded,
            total: total,
            summary: summary,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The vertical centre of a text, so two things can be compared by where they sit.
double centreOf(WidgetTester tester, Finder finder) =>
    tester.getCenter(finder).dy;

const VoiceRecapLine soap = (
  name: 'Savon de ménage',
  qty: 2,
  unit: 'PIECE',
  unitPrice: 250,
);

const VoiceRecapLine sugar = (
  name: 'Sucre',
  qty: 10,
  unit: 'SACHET',
  unitPrice: 100,
);

void main() {
  group('the heading', () {
    testWidgets('says the products were found while a confirmation waits', (
      WidgetTester tester,
    ) async {
      await pumpPanel(tester, lines: const <VoiceRecapLine>[soap]);

      expect(find.text('Produits détectés'), findsOneWidget);
      expect(find.text('Ce qui a été enregistré'), findsNothing);
    });

    testWidgets('says the command ran once it has run', (
      WidgetTester tester,
    ) async {
      // The same lines, the same figures, the same card. Only the promise differs:
      // "Produits détectés" over a written sale would say the basket is still open
      // when it is not, and the merchant would offer the same goods twice.
      await pumpPanel(
        tester,
        lines: const <VoiceRecapLine>[soap],
        isRecorded: true,
      );

      expect(find.text('Ce qui a été enregistré'), findsOneWidget);
      expect(find.text('Produits détectés'), findsNothing);
    });

    testWidgets('is absent when there is nothing under it', (
      WidgetTester tester,
    ) async {
      // A refusal, or an idle panel: a heading reading "Produits détectés" over an
      // answer that detected nothing is a heading for a list that is not there.
      await pumpPanel(tester, summary: 'Je ne peux pas faire cela');

      expect(find.text('Produits détectés'), findsNothing);
      expect(find.text('Ce qui a été enregistré'), findsNothing);
    });

    testWidgets('is present for a total with no line', (
      WidgetTester tester,
    ) async {
      await pumpPanel(tester, total: 500, isRecorded: true);

      expect(find.text('Ce qui a été enregistré'), findsOneWidget);
      expect(find.text('Montant total'), findsOneWidget);
    });
  });

  group('the total', () {
    testWidgets('is drawn once, under the lines', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        lines: const <VoiceRecapLine>[soap, sugar],
        total: 1500,
        isRecorded: true,
      );

      expect(find.text('Montant total'), findsOneWidget);
      expect(find.text('1,500 FCFA'), findsOneWidget);
      // Under the last card: the merchant reads the basket first and the figure
      // second, the other way round would put the answer before the arithmetic.
      expect(
        centreOf(tester, find.text('1,500 FCFA')),
        greaterThan(centreOf(tester, find.text('Sucre'))),
      );
    });

    testWidgets('is left out of a command that moves no money', (
      WidgetTester tester,
    ) async {
      // A stock read has no total, and printing a zero would show the merchant a
      // figure he never had.
      await pumpPanel(
        tester,
        lines: const <VoiceRecapLine>[
          (name: 'Huile de palme', qty: 0, unit: null, unitPrice: null),
        ],
      );

      expect(find.text('Montant total'), findsNothing);
      expect(find.textContaining('FCFA'), findsNothing);
    });
  });

  group('the summary', () {
    testWidgets('is asked above the products', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        lines: const <VoiceRecapLine>[soap],
        summary: 'Vous confirmez ?',
      );

      // The merchant is being asked something, and the cards are what he is being
      // asked it about. A question under the products would read as though the
      // products were the answer.
      expect(
        centreOf(tester, find.text('Vous confirmez ?')),
        lessThan(centreOf(tester, find.text('Savon de ménage'))),
      );
    });

    testWidgets('is shown without products when there are none', (
      WidgetTester tester,
    ) async {
      await pumpPanel(tester, summary: 'Combien ?');

      expect(find.text('Combien ?'), findsOneWidget);
      expect(find.text('Produits détectés'), findsNothing);
    });
  });

  group('the action row', () {
    testWidgets('is drawn under everything else', (WidgetTester tester) async {
      await pumpPanel(
        tester,
        lines: const <VoiceRecapLine>[soap],
        total: 500,
        child: const Text('Réessayer'),
      );

      expect(
        centreOf(tester, find.text('Réessayer')),
        greaterThan(centreOf(tester, find.text('Montant total'))),
      );
    });

    testWidgets('is drawn under a panel that has only a question', (
      WidgetTester tester,
    ) async {
      await pumpPanel(
        tester,
        summary: 'Lequel ?',
        child: const Text('Huile de palme'),
      );

      expect(
        centreOf(tester, find.text('Huile de palme')),
        greaterThan(centreOf(tester, find.text('Lequel ?'))),
      );
    });
  });
}
