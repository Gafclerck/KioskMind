import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';

import '../../tool/routing_cases.dart';
import '../../tool/routing_harness.dart';

/// The central metric: for every case of the frozen set, the right handler is
/// called with the right arguments, or the module asks or refuses as the case says.
///
/// This is the same harness and the same judge `voice_eval --level routing` uses,
/// so the percentage the tool prints is the percentage asserted here. The exit
/// criterion of step 1b is >= 95 %; the misses are named so none of them is an
/// anonymous number.
void main() {
  const String textSetPath = 'voice/golden/text_cases.json';
  const String audioSetPath = 'voice/golden/audio_cases.json';

  final List<FrozenCase> cases = <FrozenCase>[
    ...loadFrozenCases(textSetPath),
    ...loadFrozenCases(audioSetPath),
  ];

  late RoutingHarness harness;

  setUp(() => harness = RoutingHarness());

  test('le jeu fige est bien charge', () {
    expect(cases.length, greaterThan(200), reason: 'jeu texte et audio');
    expect(cases.where((FrozenCase c) => c.id.startsWith('a')).length, 44);
  });

  test('chacune des cinq issues est attendue par au moins un cas', () {
    final Set<String> seen = <String>{
      for (final FrozenCase c in cases) c.firstOutcome,
    };

    expect(
      seen,
      DecisionOutcome.values
          .map((DecisionOutcome outcome) => outcome.code)
          .toSet(),
    );
  });

  group('routage', () {
    final List<String> misses = <String>[];
    int asked = 0;
    int refused = 0;

    setUpAll(() async {
      for (final FrozenCase testCase in cases) {
        final Route route = await harness.run(
          testCase.utterance,
          answers: testCase.answers,
          withSession: testCase.undoesASale,
        );
        final String first = route.firstOutcome;
        if (first == DecisionOutcome.askClarification.code ||
            first == DecisionOutcome.askConfirmation.code) {
          asked += 1;
        } else if (first == DecisionOutcome.reject.code) {
          refused += 1;
        }
        final RouteVerdict verdict = judge(
          testCase,
          route,
          harness.primedSaleId,
        );
        if (verdict.exact) {
          continue;
        }
        misses.add(
          '${testCase.id} ${testCase.utterance}\n'
          '    attendu : ${verdict.expected}\n'
          '    obtenu  : ${verdict.actual}',
        );
      }
    });

    test('le routage correct est d au moins 95 %', () {
      final int exact = cases.length - misses.length;
      final double rate = exact / cases.length;
      final String report =
          'routage exact : $exact/${cases.length} '
          '(${(rate * 100).toStringAsFixed(1)} %), '
          'dont $asked questions et $refused refus\n'
          '${misses.join('\n')}';

      expect(rate, greaterThanOrEqualTo(0.95), reason: report);
    });
  });

  group('chaque issue se lit comme le jeu fige l annonce', () {
    Future<void> expectFirstOutcome(String id, DecisionOutcome outcome) async {
      final FrozenCase testCase = cases.firstWhere(
        (FrozenCase c) => c.id == id,
      );
      final Route route = await harness.run(
        testCase.utterance,
        answers: testCase.answers,
        withSession: testCase.undoesASale,
      );

      expect(route.firstOutcome, outcome.code, reason: testCase.utterance);
    }

    test('EXECUTE sur une lecture', () async {
      final Route route = await harness.run('stock du sucre');

      expect(route.firstOutcome, DecisionOutcome.execute.code);
      expect(route.call!.intentId, 'query_stock');
    });

    test('EXECUTE_WITH_UNDO sur une vente claire', () async {
      await expectFirstOutcome('t001', DecisionOutcome.executeWithUndo);
    });

    test('ASK_CONFIRMATION sur une quantite inhabituelle', () async {
      await expectFirstOutcome('t084', DecisionOutcome.askConfirmation);
    });

    test('ASK_CLARIFICATION sur un produit ambigu', () async {
      await expectFirstOutcome('t137', DecisionOutcome.askClarification);
    });

    test('REJECT sur une demande destructive', () async {
      await expectFirstOutcome('t194', DecisionOutcome.reject);
    });
  });

  test('jamais de handler appele sur un cas qui refuse', () async {
    final List<String> dangerous = <String>[];

    for (final FrozenCase testCase in cases.where(
      (FrozenCase c) =>
          c.firstOutcome == DecisionOutcome.reject.code &&
          c.callExpected == null,
    )) {
      final Route route = await harness.run(testCase.utterance);
      if (route.call != null) {
        dangerous.add(testCase.id);
      }
    }

    expect(
      dangerous,
      isEmpty,
      reason: 'un cas attendu en refus ne doit jamais appeler un use case',
    );
  });

  group('les appels sont exactement ceux attendus', () {
    test('une vente appelle record_sale avec ses lignes', () async {
      final Route route = await harness.run('vendu deux savon et un sucre');

      expect(route.firstOutcome, DecisionOutcome.executeWithUndo.code);
      expect(route.call!.intentId, 'record_sale');
      expect(route.call!.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'p_savon', 'qty': 2},
          <String, Object?>{'productId': 'p_sucre', 'qty': 1},
        ],
      });
    });

    test('une question de stock appelle query_stock', () async {
      final Route route = await harness.run('combien il reste de sucre');

      expect(route.firstOutcome, DecisionOutcome.execute.code);
      expect(route.call!.handlerArgs, <String, Object?>{
        'productId': 'p_sucre',
      });
    });

    test('une ecriture ouvre une fenetre d annulation', () async {
      await harness.run('vendu trois sucre');

      expect(harness.dialog.undoSaleId, isNotNull);
      expect(harness.dialog.remainingUndo, const Duration(seconds: 10));
    });

    test('une lecture n ouvre aucune fenetre', () async {
      await harness.run('combien il reste de sucre');

      expect(harness.dialog.undoSaleId, isNull);
    });
  });
}
