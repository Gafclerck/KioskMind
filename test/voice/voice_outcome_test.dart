import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';

/// What each handler answer becomes on the screen.
///
/// The four answers have four shapes and one screen, so this mapping is the single
/// place where they meet. It is checked answer by answer, because a recap that
/// prints a record the merchant cannot read is the failure this prevents.
void main() {
  const SaleLineResult soap = (
    productId: 'p_savon',
    name: 'Savon de menage',
    unit: 'PIECE',
    qty: 2,
    appliedUnitPrice: 250,
    resultingStock: 8,
  );
  const VoiceRecapLine soapLine = (
    name: 'Savon de menage',
    qty: 2,
    unit: 'PIECE',
  );

  group('a sale', () {
    const RecordSaleResult result = (
      saleId: 'v1',
      total: 500,
      lines: <SaleLineResult>[soap],
    );

    test('is read with its lines and its total', () {
      final VoiceOutcome? outcome = outcomeOfValue(result);

      expect(outcome, isA<SaleRecorded>());
      final SaleRecorded sale = outcome! as SaleRecorded;
      expect(sale.lines, <VoiceRecapLine>[soapLine]);
      expect(sale.total, 500);
    });
  });

  group('a restock', () {
    const RecordRestockResult result = (
      movementIds: <String>['m1'],
      lines: <RestockLineResult>[
        (
          productId: 'p_sucre',
          name: 'Sucre',
          qty: 10,
          appliedUnitCost: 400,
          resultingStock: 22,
        ),
      ],
    );

    test('is read with its lines and without a unit', () {
      final VoiceOutcome? outcome = outcomeOfValue(result);

      expect(outcome, isA<RestockRecorded>());
      expect((outcome! as RestockRecorded).lines, const <VoiceRecapLine>[
        (name: 'Sucre', qty: 10, unit: null),
      ]);
    });
  });

  group('a stock answer', () {
    const QueryStockResult result = (
      productId: 'p_huile',
      productName: 'Huile vegetale',
      stock: 5,
      unit: 'LITRE',
      alertThreshold: 3,
    );

    test('is read as the product, its quantity and its unit', () {
      final VoiceOutcome? outcome = outcomeOfValue(result);

      expect(outcome, isA<StockRead>());
      final StockRead read = outcome! as StockRead;
      expect(read.product, 'Huile vegetale');
      expect(read.stock, 5);
      expect(read.unit, 'LITRE');
    });
  });

  group('a cancellation', () {
    const CancelLastSaleResult result = (
      saleId: 'v1',
      restored: <SaleLineResult>[soap],
    );

    test('is read with the lines whose stock came back', () {
      final VoiceOutcome? outcome = outcomeOfValue(result);

      expect(outcome, isA<SaleCancelled>());
      expect((outcome! as SaleCancelled).lines, <VoiceRecapLine>[soapLine]);
    });
  });

  test('an answer this module has no use case for is left out', () {
    expect(outcomeOfValue('a string'), isNull);
    expect(outcomeOfValue(<int>[1, 2]), isNull);
  });
}
