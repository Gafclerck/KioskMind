import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

/// Builds the implementation the contract suite runs against.
///
/// The in-memory mocks call it now; phase I will call it with the real use
/// cases and get the very same expectations, so a contract gap shows up as a
/// failing test rather than as a silent difference.
typedef HandlerSubjectFactory =
    VoiceHandlers Function({
      required InMemoryProductCatalog catalog,
      required HandlerCallJournal journal,
    });

/// Runs the eighteen invariants of `docs/voice/USE_CASE_CONTRACTS.md` against any
/// set of handlers.
///
/// Each invariant is its own function: the suite is replayed verbatim against
/// the real handlers in phase I, and a contract change must be readable as one
/// difference between two named expectations.
void runIntentHandlerContract(HandlerSubjectFactory buildSubject) {
  final _Shop shop = _Shop();
  setUp(() => shop.reset(buildSubject));
  _c1SaleTotalsAndSource(shop);
  _c2MultiLineSale(shop);
  _c3NegativeStock(shop);
  _c4UnknownProduct(shop);
  _c5ArchivedProduct(shop);
  _c6InvalidQuantity(shop);
  _c7ReplayedCommand(shop);
  _c8RestockRaisesStock(shop);
  _c9RestockWithoutCost(shop);
  _c10StockQueryWrites(shop);
  _c11StockQueryUnknown(shop);
  _c12Cancellation(shop);
  _c13CancellationTwice(shop);
  _c14CancellationUnknownSale(shop);
  _c15ReplayedCancellation(shop);
  _c16EmptyItems(shop);
  _c17RestockRejectsTheSameProductsASaleDoes(shop);
  _c18StockQueryRefusesAnArchivedProduct(shop);
}

/// The store, the journal and the four handlers under test, rebuilt before each
/// invariant so one test can never lean on the state another left behind.
final class _Shop {
  static final CommandContext voice = (
    commandId: 'cmd-1',
    dateTime: DateTime(2026, 3, 1, 10),
    source: CommandSource.voice,
  );
  static final CommandContext manual = (
    commandId: 'cmd-2',
    dateTime: DateTime(2026, 3, 1, 10),
    source: CommandSource.manual,
  );

  late InMemoryProductCatalog catalog;
  late HandlerCallJournal journal;
  late RecordSaleHandler recordSale;
  late RecordRestockHandler recordRestock;
  late QueryStockHandler queryStock;
  late CancelLastSaleHandler cancelLastSale;

  void reset(HandlerSubjectFactory buildSubject) {
    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      _product('sucre', price: 100, stock: 40, unit: 'SACHET'),
      _product('lait', price: 200, stock: 12),
      _product('riz', price: 700, stock: 5, unit: 'KG'),
      _product('ancien', price: 150, stock: 3, isArchived: true),
    ]);
    journal = InMemoryCallJournal();
    final VoiceHandlers handlers = buildSubject(
      catalog: catalog,
      journal: journal,
    );
    // A missing handler is a wiring bug, not a condition the suite tolerates.
    recordSale =
        handlers.recordSale ??
        (throw StateError('Handler non branche: record_sale'));
    recordRestock =
        handlers.recordRestock ??
        (throw StateError('Handler non branche: record_restock'));
    queryStock =
        handlers.queryStock ??
        (throw StateError('Handler non branche: query_stock'));
    cancelLastSale =
        handlers.cancelLastSale ??
        (throw StateError('Handler non branche: cancel_last_sale'));
  }
}

ProductSnapshot _product(
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

T _value<T>(Result<T> result) {
  expect(result, isA<Success<T>>());
  return (result as Success<T>).value;
}

Failure _failure<T>(Result<T> result) {
  expect(result, isA<Failed<T>>());
  return (result as Failed<T>).failure;
}

void _c1SaleTotalsAndSource(_Shop shop) {
  test(
    'C1 a one-line sale totals qty times catalog price, keeps ids and source',
    () async {
      final RecordSaleResult value = _value(
        await shop.recordSale.execute(
          _Shop.voice,
          const SaleIntentInput(
            items: <SaleIntentLine>[
              SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
            ],
          ),
        ),
      );

      expect(value.saleId, 'cmd-1');
      expect(value.total, 300);
      expect(value.lines.single.appliedUnitPrice, 100);
      final StoredSale? stored = shop.catalog.saleById('cmd-1');
      expect(stored, isNotNull);
      expect(stored?.source, 'VOICE');
      expect(stored?.commandId, 'cmd-1');
      expect(stored?.dateTime, DateTime(2026, 3, 1, 10));
    },
  );
}

void _c2MultiLineSale(_Shop shop) {
  test('C2 a multi-line sale is one call that lowers every stock', () async {
    final RecordSaleResult value = _value(
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
            SaleIntentLine(productId: 'lait', productName: 'Lait', qty: 2),
          ],
        ),
      ),
    );

    expect(value.total, 700);
    expect(shop.catalog.stockOf('sucre'), 37);
    expect(shop.catalog.stockOf('lait'), 10);
    expect(shop.journal.calls, hasLength(1));
  });
}

void _c3NegativeStock(_Shop shop) {
  test(
    'C3 a sale that drives a stock negative succeeds and reports it',
    () async {
      final RecordSaleResult value = _value(
        await shop.recordSale.execute(
          _Shop.voice,
          const SaleIntentInput(
            items: <SaleIntentLine>[
              SaleIntentLine(productId: 'riz', productName: 'Riz', qty: 8),
            ],
          ),
        ),
      );

      expect(value.lines.single.resultingStock, -3);
      expect(shop.catalog.stockOf('riz'), -3);
    },
  );
}

void _c4UnknownProduct(_Shop shop) {
  test('C4 an unknown product fails and changes no stock', () async {
    final Failure failure = _failure(
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'inexistant', productName: '?', qty: 1),
          ],
        ),
      ),
    );

    expect(
      failure,
      isA<UnknownProduct>().having(
        (UnknownProduct f) => f.productId,
        'productId',
        'inexistant',
      ),
    );
    expect(shop.catalog.saleById('cmd-1'), isNull);
  });
}

void _c5ArchivedProduct(_Shop shop) {
  test('C5 an archived product fails and changes no stock', () async {
    final Failure failure = _failure(
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'ancien', productName: 'Ancien', qty: 1),
          ],
        ),
      ),
    );

    expect(failure, isA<ArchivedProduct>());
    expect(shop.catalog.saleById('cmd-1'), isNull);
  });
}

void _c6InvalidQuantity(_Shop shop) {
  test('C6 a null or negative quantity fails and changes no stock', () async {
    final Failure failure = _failure(
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 0),
          ],
        ),
      ),
    );

    expect(failure, isA<InvalidQuantity>());
    expect(shop.catalog.stockOf('sucre'), 40);
  });
}

void _c7ReplayedCommand(_Shop shop) {
  test(
    'C7 a replayed command returns the first result without a second write',
    () async {
      const SaleIntentInput input = SaleIntentInput(
        items: <SaleIntentLine>[
          SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
        ],
      );

      final RecordSaleResult first = _value(
        await shop.recordSale.execute(_Shop.voice, input),
      );
      final RecordSaleResult replayed = _value(
        await shop.recordSale.execute(_Shop.voice, input),
      );

      expect(replayed.saleId, first.saleId);
      expect(replayed.total, first.total);
      expect(replayed.lines, hasLength(first.lines.length));
      expect(replayed.lines.single.productId, 'sucre');
      expect(replayed.lines.single.qty, 3);
      expect(shop.catalog.stockOf('sucre'), 37);
    },
  );
}

void _c8RestockRaisesStock(_Shop shop) {
  test(
    'C8 a restock raises the stock and returns one movement per line',
    () async {
      final RecordRestockResult value = _value(
        await shop.recordRestock.execute(
          _Shop.voice,
          const RestockIntentInput(
            items: <RestockIntentLine>[
              RestockIntentLine(
                productId: 'lait',
                productName: 'Lait',
                qty: 24,
                spokenUnitCost: 155,
              ),
              RestockIntentLine(
                productId: 'sucre',
                productName: 'Sucre',
                qty: 10,
              ),
            ],
          ),
        ),
      );

      expect(value.movementIds, hasLength(2));
      expect(shop.catalog.stockOf('lait'), 36);
      expect(shop.catalog.stockOf('sucre'), 50);
    },
  );
}

void _c9RestockWithoutCost(_Shop shop) {
  test(
    'C9 a restock without a cost succeeds and leaves the cost unset',
    () async {
      final RecordRestockResult value = _value(
        await shop.recordRestock.execute(
          _Shop.voice,
          const RestockIntentInput(
            items: <RestockIntentLine>[
              RestockIntentLine(
                productId: 'sucre',
                productName: 'Sucre',
                qty: 10,
              ),
            ],
          ),
        ),
      );

      expect(value.lines.single.appliedUnitCost, isNull);
    },
  );
}

void _c10StockQueryWrites(_Shop shop) {
  test(
    'C10 a stock query answers from the catalog and writes nothing',
    () async {
      final QueryStockResult value = _value(
        await shop.queryStock.execute(
          _Shop.manual,
          const QueryStockInput(productId: 'sucre'),
        ),
      );

      expect(value.productName, 'sucre');
      expect(value.stock, 40);
      expect(value.unit, 'SACHET');
      expect(shop.catalog.saleById('cmd-2'), isNull);
      expect(shop.catalog.movements, isEmpty);
    },
  );
}

void _c11StockQueryUnknown(_Shop shop) {
  test('C11 a stock query on an unknown product fails', () async {
    final Failure failure = _failure(
      await shop.queryStock.execute(
        _Shop.manual,
        const QueryStockInput(productId: 'inexistant'),
      ),
    );

    expect(failure, isA<UnknownProduct>());
  });
}

void _c12Cancellation(_Shop shop) {
  test(
    'C12 cancelling flags the sale, restores the stock and keeps it',
    () async {
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
            SaleIntentLine(productId: 'lait', productName: 'Lait', qty: 2),
          ],
        ),
      );
      expect(shop.catalog.stockOf('sucre'), 37);

      final CancelLastSaleResult value = _value(
        await shop.cancelLastSale.execute(
          _Shop.voice,
          const CancelLastSaleInput(saleId: 'cmd-1'),
        ),
      );

      expect(value.saleId, 'cmd-1');
      expect(value.restored, hasLength(2));
      expect(shop.catalog.stockOf('sucre'), 40);
      expect(shop.catalog.stockOf('lait'), 12);
      expect(shop.catalog.saleById('cmd-1')?.cancelledAt, isNotNull);
    },
  );
}

void _c13CancellationTwice(_Shop shop) {
  test(
    'C13 cancelling twice fails and does not restore the stock twice',
    () async {
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
          ],
        ),
      );
      await shop.cancelLastSale.execute(
        _Shop.voice,
        const CancelLastSaleInput(saleId: 'cmd-1'),
      );

      final Failure failure = _failure(
        await shop.cancelLastSale.execute(
          _Shop.voice,
          const CancelLastSaleInput(saleId: 'cmd-1'),
        ),
      );

      expect(failure, isA<AlreadyCancelled>());
      expect(shop.catalog.stockOf('sucre'), 40);
    },
  );
}

void _c14CancellationUnknownSale(_Shop shop) {
  test('C14 cancelling an unknown sale fails', () async {
    final Failure failure = _failure(
      await shop.cancelLastSale.execute(
        _Shop.voice,
        const CancelLastSaleInput(saleId: 'inconnue'),
      ),
    );

    expect(failure, isA<SaleNotFound>());
  });
}

void _c15ReplayedCancellation(_Shop shop) {
  test(
    'C15 a replayed cancellation does not restore the stock twice',
    () async {
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'sucre', productName: 'Sucre', qty: 3),
          ],
        ),
      );
      const CancelLastSaleInput input = CancelLastSaleInput(saleId: 'cmd-1');

      expect(
        await shop.cancelLastSale.execute(_Shop.voice, input),
        isA<Success<CancelLastSaleResult>>(),
      );
      expect(
        await shop.cancelLastSale.execute(_Shop.voice, input),
        isA<Failed<CancelLastSaleResult>>(),
      );
      expect(shop.catalog.stockOf('sucre'), 40);
    },
  );
}

void _c16EmptyItems(_Shop shop) {
  test('C16 an empty item list fails on both write intents', () async {
    final Failure saleFailure = _failure(
      await shop.recordSale.execute(
        _Shop.voice,
        const SaleIntentInput(items: <SaleIntentLine>[]),
      ),
    );
    final Failure restockFailure = _failure(
      await shop.recordRestock.execute(
        _Shop.voice,
        const RestockIntentInput(items: <RestockIntentLine>[]),
      ),
    );

    expect(saleFailure, isA<EmptyItems>());
    expect(restockFailure, isA<EmptyItems>());
  });
}

void _c17RestockRejectsTheSameProductsASaleDoes(_Shop shop) {
  test(
    'C17 restock refuses unknown, archived and non-positive entries',
    () async {
      Future<Failure> reject(String productId, double qty) {
        return shop.recordRestock
            .execute(
              _Shop.voice,
              RestockIntentInput(
                items: <RestockIntentLine>[
                  RestockIntentLine(
                    productId: productId,
                    productName: productId,
                    qty: qty,
                  ),
                ],
              ),
            )
            .then(_failure<RecordRestockResult>);
      }

      expect(await reject('inexistant', 1), isA<UnknownProduct>());
      expect(await reject('ancien', 1), isA<ArchivedProduct>());
      expect(await reject('lait', 0), isA<InvalidQuantity>());
      expect(shop.catalog.stockOf('lait'), 12);
      expect(shop.catalog.movements, isEmpty);
    },
  );
}

void _c18StockQueryRefusesAnArchivedProduct(_Shop shop) {
  test('C18 a stock query refuses an archived product', () async {
    final Failure failure = _failure(
      await shop.queryStock.execute(
        _Shop.manual,
        const QueryStockInput(productId: 'ancien'),
      ),
    );

    expect(failure, isA<ArchivedProduct>());
  });
}
