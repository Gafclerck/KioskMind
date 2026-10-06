import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/fact_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/fact_preserving_guard.dart';

void main() {
  group('FactPreservingGuard', () {
    const FactPreservingGuard guard = FactPreservingGuard(threshold: 100.0);

    test(
      'accepts naturally formulated response when all numbers match facts',
      () {
        const FactResult fact = FactResult(
          operation: 'record_sale',
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'product': 'Riz', 'qty': 2, 'price': 10000},
            ],
            'total': 10000,
          },
        );

        expect(
          () => guard.check(
            [fact],
            "C'est noté ! J'ai bien enregistré la vente de 2 sacs de Riz pour un total de 10 000 FCFA.",
          ),
          returnsNormally,
        );
      },
    );

    test(
      'rejects invented numbers above threshold (e.g. hallucinated calculation)',
      () {
        const FactResult fact = FactResult(
          operation: 'record_sale',
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'product': 'Savon', 'qty': 3, 'price': 1500},
            ],
            'total': 1500,
          },
        );

        expect(
          () => guard.check(
            [fact],
            "Vente enregistrée pour 1 500 FCFA. Il vous reste un solde théorique de 45 000 FCFA.",
          ),
          throwsA(isA<GuardViolationException>()),
        );
      },
    );

    test('tolerates small conversational counters below threshold', () {
      const FactResult fact = FactResult(
        operation: 'record_sale',
        data: <String, dynamic>{'total': 5000},
      );

      // "2 articles" is 2 < 100, so it is tolerated even though not in the facts map explicitly
      expect(
        () => guard.check([
          fact,
        ], "Parfait, j'ai validé vos 2 articles pour 5 000 FCFA."),
        returnsNormally,
      );
    });

    test(
      'normalizes numbers in French style with spaces, commas, and dots',
      () {
        expect(guard.normalizeNumber('40 000'), 40000);
        expect(guard.normalizeNumber('40.000'), 40000);
        expect(guard.normalizeNumber('1 250,50'), 1250.5);
        expect(guard.normalizeNumber('12,5'), 12.5);
        expect(guard.normalizeNumber('500'), 500);
      },
    );
  });
}
