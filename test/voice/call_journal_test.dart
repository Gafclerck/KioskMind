import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/canonical_arguments.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/journaling_intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_query_stock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

void main() {
  group('canonicalValue', () {
    test('turns an integral double into an integer', () {
      expect(canonicalValue(2.0), 2);
      expect(canonicalValue(2.5), 2.5);
    });

    test('rounds binary noise to two decimals', () {
      expect(canonicalValue(0.1 + 0.2), closeTo(0.3, 1e-9));
    });

    test('leaves strings, nulls and lists of strings untouched', () {
      expect(canonicalValue('sucre'), 'sucre');
      expect(canonicalValue(null), isNull);
      expect(canonicalValue(<Object?>['a', 1.0]), <Object?>['a', 1]);
    });
  });

  group('IntentInput.toArguments', () {
    test('keeps only what determines the call for a stock query', () {
      const QueryStockInput input = QueryStockInput(productId: 'sucre');
      expect(input.toArguments(), <String, Object?>{'productId': 'sucre'});
    });

    test('exposes per-line quantity and product for a sale', () {
      const SaleIntentInput input = SaleIntentInput(
        items: <SaleIntentLine>[
          SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 2),
          SaleIntentLine(
            productId: 'lait',
            productName: 'Lait',
            qty: 1,
            spokenUnitPrice: 250,
          ),
        ],
      );
      expect(input.toArguments(), <String, Object?>{
        'items': <Map<String, Object?>>[
          <String, Object?>{'productId': 'sucre', 'qty': 2.0},
          <String, Object?>{'productId': 'lait', 'qty': 1.0},
        ],
      });
    });

    test('carries the sale identifier a cancellation targets', () {
      const CancelLastSaleInput input = CancelLastSaleInput(saleId: 'cmd-1');
      expect(input.toArguments(), <String, Object?>{'saleId': 'cmd-1'});
    });

    test('adds the spoken cost to a restock line when there is one', () {
      const RestockIntentInput input = RestockIntentInput(
        items: <RestockIntentLine>[
          RestockIntentLine(productId: 'riz', productName: 'Riz', qty: 20),
          RestockIntentLine(
            productId: 'huile',
            productName: 'Huile',
            qty: 5,
            spokenUnitCost: 900,
          ),
        ],
      );
      expect(input.toArguments(), <String, Object?>{
        'items': <Map<String, Object?>>[
          <String, Object?>{'productId': 'riz', 'qty': 20.0},
          <String, Object?>{
            'productId': 'huile',
            'qty': 5.0,
            'unitCost': 900.0,
          },
        ],
      });
    });
  });

  group('JournalingIntentHandler', () {
    late InMemoryProductCatalog catalog;
    late InMemoryCallJournal journal;
    late QueryStockHandler handler;

    final CommandContext voice = (
      commandId: 'cmd-1',
      dateTime: DateTime(2026, 3, 1, 10),
      source: CommandSource.voice,
    );

    setUp(() {
      catalog = InMemoryProductCatalog(<ProductSnapshot>[
        const ProductSnapshot(
          id: 'sucre',
          name: 'Sucre',
          aliases: <String>[],
          unit: 'SACHET',
          price: 100,
          purchasePrice: 75,
          stock: 40,
          alertThreshold: 10,
          averageDailyQty: 6,
        ),
      ]);
      journal = InMemoryCallJournal();
      handler = JournalingIntentHandler<QueryStockInput, QueryStockResult>(
        MockQueryStockHandler(catalog),
        journal,
      );
    });

    test('records the intent and its canonical arguments', () async {
      await handler.execute(voice, const QueryStockInput(productId: 'sucre'));

      expect(journal.calls, hasLength(1));
      final HandlerCall call = journal.calls.single;
      expect(call.intentId, 'query_stock');
      expect(call.handlerArgs, <String, Object?>{'productId': 'sucre'});
    });

    test('records the call even when the handler fails', () async {
      await handler.execute(voice, const QueryStockInput(productId: 'inconnu'));

      expect(journal.calls, hasLength(1));
      expect(journal.calls.single.intentId, 'query_stock');
    });

    test('does not leak a displayable name into the arguments', () async {
      await handler.execute(voice, const QueryStockInput(productId: 'sucre'));

      expect(journal.calls.single.handlerArgs.keys, <String>['productId']);
    });

    test('exposes a snapshot that cannot corrupt the run', () async {
      await handler.execute(voice, const QueryStockInput(productId: 'sucre'));

      expect(
        () => journal.calls.add((
          intentId: 'record_sale',
          handlerArgs: <String, Object?>{},
        )),
        throwsUnsupportedError,
      );
    });

    test('forgets previous calls on clear', () async {
      await handler.execute(voice, const QueryStockInput(productId: 'sucre'));
      journal.clear();
      expect(journal.calls, isEmpty);
    });
  });
}
