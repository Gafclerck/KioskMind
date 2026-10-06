import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';
import 'package:kiosk_mind/features/sales/domain/exceptions/sales_exceptions.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/sales_repository.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/cancel_sale.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/record_sale.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_cancel_last_sale_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_record_sale_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';

final class _FakeSalesRepository implements SalesRepository {
  final Map<String, Sale> sales = <String, Sale>{};

  @override
  Future<Sale> recordSale(Sale sale) async {
    final id = sale.id ?? 'gen-${sales.length + 1}';

    final saved = Sale(
      id: id,
      dateTime: sale.dateTime,
      createdAt: sale.createdAt,
      total: sale.total,
      items: sale.items,
      source: sale.source,
      status: sale.status,
      cancelledAt: sale.cancelledAt,
    );

    sales[id] = saved;

    return saved;
  }

  @override
  Future<Sale> updateSale(Sale sale) async {
    final saleId = sale.id;

    if (saleId == null || saleId.isEmpty) {
      throw SaleNotFoundException('');
    }

    final existing = sales[saleId];

    if (existing == null) {
      throw SaleNotFoundException(saleId);
    }

    if (existing.status == 'CANCELLED' || existing.cancelledAt != null) {
      throw AlreadyCancelledException(saleId);
    }

    final updated = Sale(
      id: existing.id,
      dateTime: sale.dateTime,
      createdAt: existing.createdAt,
      total: sale.total,
      items: sale.items,
      source: existing.source,
      status: existing.status,
      cancelledAt: null,
    );

    sales[saleId] = updated;

    return updated;
  }

  @override
  Future<Sale> cancelSale(String saleId) async {
    final existing = sales[saleId];

    if (existing == null) {
      throw SaleNotFoundException(saleId);
    }

    if (existing.status == 'CANCELLED' || existing.cancelledAt != null) {
      throw AlreadyCancelledException(saleId);
    }

    final cancelled = Sale(
      id: existing.id,
      dateTime: existing.dateTime,
      createdAt: existing.createdAt,
      total: existing.total,
      items: existing.items,
      source: existing.source,
      status: 'CANCELLED',
      cancelledAt: DateTime(2026, 3, 1, 12),
    );

    sales[saleId] = cancelled;

    return cancelled;
  }

  @override
  Future<List<Sale>> getSalesHistory() async {
    return sales.values.toList();
  }

  @override
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return sales.values.toList();
  }

  @override
Stream<List<Sale>> watchSalesHistory() {
  return const Stream.empty();
}

}

ProductSnapshot _product(
  String id, {
  required String name,
  required double price,
  required double stock,
  String unit = 'PIECE',
  bool isArchived = false,
}) {
  return ProductSnapshot(
    id: id,
    name: name,
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

void main() {
  late _FakeSalesRepository salesRepo;
  late InMemoryProductCatalog catalog;
  late RealRecordSaleHandler recordSaleHandler;
  late RealCancelLastSaleHandler cancelLastSaleHandler;

  final CommandContext context = (
    commandId: 'cmd-v1',
    dateTime: DateTime(2026, 3, 1, 10),
    source: CommandSource.voice,
  );

  setUp(() {
    salesRepo = _FakeSalesRepository();

    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      _product('p_sucre', name: 'Sucre', price: 500, stock: 20, unit: 'KG'),
      _product('p_lait', name: 'Lait', price: 250, stock: 10, unit: 'BOITE'),
      _product(
        'p_ancien',
        name: 'Ancien',
        price: 100,
        stock: 2,
        isArchived: true,
      ),
    ]);

    recordSaleHandler = RealRecordSaleHandler(
      recordSale: RecordSale(salesRepo),
      catalogReader: catalog,
    );

    cancelLastSaleHandler = RealCancelLastSaleHandler(
      cancelSale: CancelSale(salesRepo),
      catalogReader: catalog,
    );
  });

  group('RealRecordSaleHandler', () {
    test('records a sale and delegates to RecordSale usecase', () async {
      final input = const SaleIntentInput(
        items: [
          SaleIntentLine(
            productId: 'p_sucre',
            productName: 'Sucre',
            qty: 2,
            spokenUnitPrice: 500,
          ),
        ],
      );

      final result = await recordSaleHandler.execute(context, input);

      expect(result, isA<Success<RecordSaleResult>>());

      final success = result as Success<RecordSaleResult>;

      expect(success.value.saleId, equals('cmd-v1'));
      expect(success.value.total, equals(1000));
      expect(success.value.lines.first.resultingStock, equals(18));
      expect(salesRepo.sales['cmd-v1'], isNotNull);
    });

    test(
      'replayed command returns previous result without duplicate write',
      () async {
        final input = const SaleIntentInput(
          items: [
            SaleIntentLine(
              productId: 'p_sucre',
              productName: 'Sucre',
              qty: 1,
              spokenUnitPrice: 500,
            ),
          ],
        );

        final first = await recordSaleHandler.execute(context, input);
        final second = await recordSaleHandler.execute(context, input);

        expect(first, isA<Success<RecordSaleResult>>());
        expect(second, isA<Success<RecordSaleResult>>());

        expect(
          (first as Success<RecordSaleResult>).value.total,
          equals((second as Success<RecordSaleResult>).value.total),
        );
      },
    );

    test('refuses empty items', () async {
      const input = SaleIntentInput(items: []);

      final result = await recordSaleHandler.execute(context, input);

      expect(result, isA<Failed<RecordSaleResult>>());

      expect((result as Failed<RecordSaleResult>).failure, isA<EmptyItems>());
    });

    test('refuses unknown product', () async {
      const input = SaleIntentInput(
        items: [
          SaleIntentLine(productId: 'unknown', productName: 'Inconnu', qty: 1),
        ],
      );

      final result = await recordSaleHandler.execute(context, input);

      expect(result, isA<Failed<RecordSaleResult>>());

      expect(
        (result as Failed<RecordSaleResult>).failure,
        isA<UnknownProduct>(),
      );
    });

    test('refuses archived product', () async {
      const input = SaleIntentInput(
        items: [
          SaleIntentLine(productId: 'p_ancien', productName: 'Ancien', qty: 1),
        ],
      );

      final result = await recordSaleHandler.execute(context, input);

      expect(result, isA<Failed<RecordSaleResult>>());

      expect(
        (result as Failed<RecordSaleResult>).failure,
        isA<ArchivedProduct>(),
      );
    });

    test('refuses invalid quantity <= 0', () async {
      const input = SaleIntentInput(
        items: [
          SaleIntentLine(productId: 'p_sucre', productName: 'Sucre', qty: 0),
        ],
      );

      final result = await recordSaleHandler.execute(context, input);

      expect(result, isA<Failed<RecordSaleResult>>());

      expect(
        (result as Failed<RecordSaleResult>).failure,
        isA<InvalidQuantity>(),
      );
    });
  });

  group('RealCancelLastSaleHandler', () {
    test('cancels sale and restores line items', () async {
      salesRepo.sales['sale-abc'] = Sale(
        id: 'sale-abc',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 1000,
        items: [
          SaleItem(productId: 'p_sucre', name: 'Sucre', qty: 2, unitPrice: 500),
        ],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      final result = await cancelLastSaleHandler.execute(
        context,
        const CancelLastSaleInput(saleId: 'sale-abc'),
      );

      expect(result, isA<Success<CancelLastSaleResult>>());

      final success = result as Success<CancelLastSaleResult>;

      expect(success.value.saleId, equals('sale-abc'));
      expect(success.value.restored.length, equals(1));
      expect(success.value.restored.first.qty, equals(2));
      expect(success.value.restored.first.resultingStock, equals(20));
      expect(salesRepo.sales['sale-abc']?.status, equals('CANCELLED'));
    });

    test('returns SaleNotFound when sale is absent', () async {
      final result = await cancelLastSaleHandler.execute(
        context,
        const CancelLastSaleInput(saleId: 'missing-id'),
      );

      expect(result, isA<Failed<CancelLastSaleResult>>());

      expect(
        (result as Failed<CancelLastSaleResult>).failure,
        isA<SaleNotFound>(),
      );
    });

    test('returns AlreadyCancelled when sale is cancelled twice', () async {
      salesRepo.sales['sale-twice'] = Sale(
        id: 'sale-twice',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 500,
        items: [],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      await cancelLastSaleHandler.execute(
        context,
        const CancelLastSaleInput(saleId: 'sale-twice'),
      );

      final second = await cancelLastSaleHandler.execute(
        context,
        const CancelLastSaleInput(saleId: 'sale-twice'),
      );

      expect(second, isA<Failed<CancelLastSaleResult>>());

      expect(
        (second as Failed<CancelLastSaleResult>).failure,
        isA<AlreadyCancelled>(),
      );
    });
  });
}
