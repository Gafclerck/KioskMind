import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

/// Builds an implementation to run the contract suite against.
///
/// The in-memory mocks call it now; phase I will call it with real use cases
/// and get the very same expectations, so a contract gap shows up as a failure
/// rather than as a silent difference.
typedef HandlerSubjectFactory =
    VoiceHandlers Function({
      required InMemoryProductCatalog catalog,
      required HandlerCallJournal journal,
    });

/// Runs the sixteen invariants of `docs/voice/USE_CASE_CONTRACTS.md` against
/// any set of handlers.
///
/// Each test is written against the catalog fixture, not against the mock's own
/// internals: the assertions describe the contract, so a change in how the mock
/// stores things cannot make them pass.
void runIntentHandlerContract(HandlerSubjectFactory buildSubject) {
  late InMemoryProductCatalog catalog;
  late HandlerCallJournal journal;
  late VoiceHandlers handlers;
  late CommandContext voice;
  late CommandContext manual;

  ProductSnapshot product(
    String id, {
    required double price,
    required double stock,
    String unit = 'PIECE',
    bool isArchived = false,
  }) {
    return ProductSnapshot(
      id: id,
      name: id,
      aliases: const <String>[],
      unit: unit,
      price: price,
      purchasePrice: null,
      stock: stock,
      alertThreshold: 0,
      averageDailyQty: 0,
      isArchived: isArchived,
    );
  }

  CommandContext contextAt(String commandId, CommandSource source) {
    return (
      commandId: commandId,
      dateTime: DateTime(2026, 3, 1, 10),
      source: source,
    );
  }

  setUp(() {
    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      product('sucre', price: 100, stock: 40, unit: 'SACHET'),
      product('lait', price: 200, stock: 12),
      product('riz', price: 700, stock: 5, unit: 'KG'),
      product('ancien', price: 150, stock: 3, isArchived: true),
    ]);
    journal = _RecordingJournal();
    handlers = buildSubject(catalog: catalog, journal: journal);
    voice = contextAt('cmd-1', CommandSource.voice);
    manual = contextAt('cmd-2', CommandSource.manual);
  });

  SaleIntentInput sale(List<SaleIntentLine> items) =>
      SaleIntentInput(items: items);

  RestockIntentInput restock(List<RestockIntentLine> items) =>
      RestockIntentInput(items: items);

  group('contract', () {
    test(
      'C1 a one-line sale totals qty times catalog price, keeps its ids and source',
      () async {
        final Result<RecordSaleResult> result = await handlers.recordSale!
            .execute(
              voice,
              sale(<SaleIntentLine>[
                const SaleIntentLine(
                  productId: 'sucre',
                  productName: 'Sucre',
                  qty: 3,
                ),
              ]),
            );

        expect(result, isA<Success<RecordSaleResult>>());
        final RecordSaleResult value =
            (result as Success<RecordSaleResult>).value;
        expect(value.saleId, 'cmd-1');
        expect(value.total, 300);
        expect(value.lines.single.appliedUnitPrice, 100);

        final StoredSale stored = catalog.saleById('cmd-1')!;
        expect(stored.source, 'VOICE');
        expect(stored.commandId, 'cmd-1');
        expect(stored.dateTime, DateTime(2026, 3, 1, 10));
      },
    );

    test(
      'C2 a multi-line sale is a single call that lowers every stock',
      () async {
        final Result<RecordSaleResult> result = await handlers.recordSale!
            .execute(
              voice,
              sale(<SaleIntentLine>[
                const SaleIntentLine(
                  productId: 'sucre',
                  productName: 'Sucre',
                  qty: 3,
                ),
                const SaleIntentLine(
                  productId: 'lait',
                  productName: 'Lait',
                  qty: 2,
                ),
              ]),
            );

        expect(result, isA<Success<RecordSaleResult>>());
        expect((result as Success<RecordSaleResult>).value.total, 700);
        expect(catalog.stockOf('sucre'), 37);
        expect(catalog.stockOf('lait'), 10);
      },
    );

    test(
      'C3 a sale that drives a stock negative succeeds and reports it',
      () async {
        final Result<RecordSaleResult> result = await handlers.recordSale!
            .execute(
              voice,
              sale(<SaleIntentLine>[
                const SaleIntentLine(
                  productId: 'riz',
                  productName: 'Riz',
                  qty: 8,
                ),
              ]),
            );

        expect(result, isA<Success<RecordSaleResult>>());
        final RecordSaleResult value =
            (result as Success<RecordSaleResult>).value;
        expect(value.lines.single.resultingStock, -3);
        expect(catalog.stockOf('riz'), -3);
      },
    );

    test('C4 an unknown product fails and changes no stock', () async {
      final Result<RecordSaleResult> result = await handlers.recordSale!
          .execute(
            voice,
            sale(<SaleIntentLine>[
              const SaleIntentLine(
                productId: 'inexistant',
                productName: '?',
                qty: 1,
              ),
            ]),
          );

      expect(
        result,
        isA<Failed<RecordSaleResult>>().having(
          (Failed<RecordSaleResult> failed) => failed.failure,
          'failure',
          isA<UnknownProduct>().having(
            (UnknownProduct failure) => failure.productId,
            'productId',
            'inexistant',
          ),
        ),
      );
      expect(catalog.saleById('cmd-1'), isNull);
    });

    test('C5 an archived product fails and changes no stock', () async {
      final Result<RecordSaleResult> result = await handlers.recordSale!
          .execute(
            voice,
            sale(<SaleIntentLine>[
              const SaleIntentLine(
                productId: 'ancien',
                productName: 'Ancien',
                qty: 1,
              ),
            ]),
          );

      expect(
        result,
        isA<Failed<RecordSaleResult>>().having(
          (Failed<RecordSaleResult> failed) => failed.failure,
          'failure',
          isA<ArchivedProduct>(),
        ),
      );
      expect(catalog.saleById('cmd-1'), isNull);
    });

    test('C6 a null or negative quantity fails and changes no stock', () async {
      final Result<RecordSaleResult> result = await handlers.recordSale!
          .execute(
            voice,
            sale(<SaleIntentLine>[
              const SaleIntentLine(
                productId: 'sucre',
                productName: 'Sucre',
                qty: 0,
              ),
            ]),
          );

      expect(
        result,
        isA<Failed<RecordSaleResult>>().having(
          (Failed<RecordSaleResult> failed) => failed.failure,
          'failure',
          isA<InvalidQuantity>(),
        ),
      );
      expect(catalog.stockOf('sucre'), 40);
    });

    test(
      'C7 a replayed command returns the first result without a second write',
      () async {
        final SaleIntentInput input = sale(<SaleIntentLine>[
          const SaleIntentLine(
            productId: 'sucre',
            productName: 'Sucre',
            qty: 3,
          ),
        ]);

        final Result<RecordSaleResult> first = await handlers.recordSale!
            .execute(voice, input);
        final Result<RecordSaleResult> replayed = await handlers.recordSale!
            .execute(voice, input);

        expect(replayed, isA<Success<RecordSaleResult>>());
        expect(
          (replayed as Success<RecordSaleResult>).value,
          (first as Success<RecordSaleResult>).value,
        );
        expect(catalog.stockOf('sucre'), 37);
      },
    );

    test(
      'C8 a restock raises the stock and returns one movement per line',
      () async {
        final Result<RecordRestockResult> result = await handlers.recordRestock!
            .execute(
              voice,
              restock(<RestockIntentLine>[
                const RestockIntentLine(
                  productId: 'lait',
                  productName: 'Lait',
                  qty: 24,
                  spokenUnitCost: 155,
                ),
                const RestockIntentLine(
                  productId: 'sucre',
                  productName: 'Sucre',
                  qty: 10,
                ),
              ]),
            );

        expect(result, isA<Success<RecordRestockResult>>());
        final RecordRestockResult value =
            (result as Success<RecordRestockResult>).value;
        expect(value.movementIds, hasLength(2));
        expect(catalog.stockOf('lait'), 36);
        expect(catalog.stockOf('sucre'), 50);
      },
    );

    test(
      'C9 a restock without a cost succeeds and leaves the cost unset',
      () async {
        final Result<RecordRestockResult> result = await handlers.recordRestock!
            .execute(
              voice,
              restock(<RestockIntentLine>[
                const RestockIntentLine(
                  productId: 'sucre',
                  productName: 'Sucre',
                  qty: 10,
                ),
              ]),
            );

        expect(result, isA<Success<RecordRestockResult>>());
        expect(
          (result as Success<RecordRestockResult>)
              .value
              .lines
              .single
              .appliedUnitCost,
          isNull,
        );
      },
    );

    test(
      'C10 a stock query answers from the catalog and writes nothing',
      () async {
        final Result<QueryStockResult> result = await handlers.queryStock!
            .execute(manual, const QueryStockInput(productId: 'sucre'));

        expect(result, isA<Success<QueryStockResult>>());
        final QueryStockResult value =
            (result as Success<QueryStockResult>).value;
        expect(value.productName, 'sucre');
        expect(value.stock, 40);
        expect(value.unit, 'SACHET');
        expect(catalog.saleById('cmd-2'), isNull);
        expect(catalog.movements, isEmpty);
      },
    );

    test('C11 a stock query on an unknown product fails', () async {
      final Result<QueryStockResult> result = await handlers.queryStock!
          .execute(manual, const QueryStockInput(productId: 'inexistant'));

      expect(
        result,
        isA<Failed<QueryStockResult>>().having(
          (Failed<QueryStockResult> failed) => failed.failure,
          'failure',
          isA<UnknownProduct>(),
        ),
      );
    });

    test(
      'C12 cancelling flags the sale, restores the stock and keeps the document',
      () async {
        await handlers.recordSale!.execute(
          voice,
          sale(<SaleIntentLine>[
            const SaleIntentLine(
              productId: 'sucre',
              productName: 'Sucre',
              qty: 3,
            ),
            const SaleIntentLine(
              productId: 'lait',
              productName: 'Lait',
              qty: 2,
            ),
          ]),
        );
        expect(catalog.stockOf('sucre'), 37);

        final Result<CancelLastSaleResult> result = await handlers
            .cancelLastSale!
            .execute(voice, const CancelLastSaleInput(saleId: 'cmd-1'));

        expect(result, isA<Success<CancelLastSaleResult>>());
        final CancelLastSaleResult value =
            (result as Success<CancelLastSaleResult>).value;
        expect(value.saleId, 'cmd-1');
        expect(value.restored, hasLength(2));
        expect(catalog.stockOf('sucre'), 40);
        expect(catalog.stockOf('lait'), 12);

        final StoredSale stored = catalog.saleById('cmd-1')!;
        expect(stored, isNotNull);
        expect(stored.cancelledAt, isNotNull);
      },
    );

    test(
      'C13 cancelling twice fails and does not restore the stock twice',
      () async {
        await handlers.recordSale!.execute(
          voice,
          sale(<SaleIntentLine>[
            const SaleIntentLine(
              productId: 'sucre',
              productName: 'Sucre',
              qty: 3,
            ),
          ]),
        );
        await handlers.cancelLastSale!.execute(
          voice,
          const CancelLastSaleInput(saleId: 'cmd-1'),
        );

        final Result<CancelLastSaleResult> again = await handlers
            .cancelLastSale!
            .execute(voice, const CancelLastSaleInput(saleId: 'cmd-1'));

        expect(
          again,
          isA<Failed<CancelLastSaleResult>>().having(
            (Failed<CancelLastSaleResult> failed) => failed.failure,
            'failure',
            isA<AlreadyCancelled>(),
          ),
        );
        expect(catalog.stockOf('sucre'), 40);
      },
    );

    test('C14 cancelling an unknown sale fails', () async {
      final Result<CancelLastSaleResult> result = await handlers.cancelLastSale!
          .execute(voice, const CancelLastSaleInput(saleId: 'inconnue'));

      expect(
        result,
        isA<Failed<CancelLastSaleResult>>().having(
          (Failed<CancelLastSaleResult> failed) => failed.failure,
          'failure',
          isA<SaleNotFound>(),
        ),
      );
    });

    test(
      'C15 a replayed cancellation does not restore the stock twice',
      () async {
        await handlers.recordSale!.execute(
          voice,
          sale(<SaleIntentLine>[
            const SaleIntentLine(
              productId: 'sucre',
              productName: 'Sucre',
              qty: 3,
            ),
          ]),
        );

        final CancelLastSaleInput input = const CancelLastSaleInput(
          saleId: 'cmd-1',
        );
        final Result<CancelLastSaleResult> first = await handlers
            .cancelLastSale!
            .execute(voice, input);
        final Result<CancelLastSaleResult> replayed = await handlers
            .cancelLastSale!
            .execute(voice, input);

        expect(first, isA<Success<CancelLastSaleResult>>());
        expect(replayed, isA<Failed<CancelLastSaleResult>>());
        expect(catalog.stockOf('sucre'), 40);
      },
    );

    test('C16 an empty item list fails on both write intents', () async {
      final Result<RecordSaleResult> saleResult = await handlers.recordSale!
          .execute(voice, const SaleIntentInput(items: <SaleIntentLine>[]));
      final Result<RecordRestockResult> restockResult = await handlers
          .recordRestock!
          .execute(
            voice,
            const RestockIntentInput(items: <RestockIntentLine>[]),
          );

      expect(
        (saleResult as Failed<RecordSaleResult>).failure,
        isA<EmptyItems>(),
      );
      expect(
        (restockResult as Failed<RecordRestockResult>).failure,
        isA<EmptyItems>(),
      );
    });
  });
}

final class _RecordingJournal implements HandlerCallJournal {
  final List<HandlerCall> _calls = <HandlerCall>[];

  @override
  void record(HandlerCall call) => _calls.add(call);

  @override
  List<HandlerCall> get calls => _calls;

  @override
  void clear() => _calls.clear();
}
