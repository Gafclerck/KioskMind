import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';
import 'package:kiosk_mind/features/sales/domain/exceptions/sales_exceptions.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/sales_repository.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/cancel_sale.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/record_sale.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/update_sale.dart';

final class _FakeSalesRepository implements SalesRepository {
  final Map<String, Sale> sales = <String, Sale>{};

  @override
  Future<Sale> recordSale(Sale sale) async {
    final id = sale.id ?? 'generated-${sales.length + 1}';

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
    return sales.values
        .where(
          (s) =>
              !s.dateTime.isBefore(startDate) && s.dateTime.isBefore(endDate),
        )
        .toList();
  }

  @override
Stream<List<Sale>> watchSalesHistory() {
  return const Stream.empty();
}

}

void main() {
  late _FakeSalesRepository repository;
  late RecordSale recordSale;
  late UpdateSale updateSale;
  late CancelSale cancelSale;

  setUp(() {
    repository = _FakeSalesRepository();
    recordSale = RecordSale(repository);
    updateSale = UpdateSale(repository);
    cancelSale = CancelSale(repository);
  });

  group('RecordSale use case', () {
    test('records a sale and preserves client command id', () async {
      final sale = Sale(
        id: 'cmd-123',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 500,
        items: [
          SaleItem(productId: 'sucre', name: 'Sucre', qty: 2, unitPrice: 250),
        ],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      final result = await recordSale(sale);

      expect(result.id, equals('cmd-123'));
      expect(result.total, equals(500));
      expect(repository.sales['cmd-123'], isNotNull);
    });

    test('generates an id when not provided', () async {
      final sale = Sale(
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 200,
        items: [
          SaleItem(productId: 'lait', name: 'Lait', qty: 1, unitPrice: 200),
        ],
        source: 'MANUAL',
        status: 'COMPLETED',
      );

      final result = await recordSale(sale);

      expect(result.id, isNotNull);
      expect(result.id, isNotEmpty);
    });
  });

  group('UpdateSale use case', () {
    test('updates an existing sale', () async {
      final sale = Sale(
        id: 'sale-update-1',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 300,
        items: [
          SaleItem(productId: 'sucre', name: 'Sucre', qty: 3, unitPrice: 100),
        ],
        source: 'MANUAL',
        status: 'COMPLETED',
      );

      await recordSale(sale);

      final updatedSale = Sale(
        id: 'sale-update-1',
        dateTime: DateTime(2026, 3, 1, 11),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 500,
        items: [
          SaleItem(productId: 'sucre', name: 'Sucre', qty: 5, unitPrice: 100),
        ],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      final result = await updateSale(updatedSale);

      expect(result.id, equals('sale-update-1'));
      expect(result.total, equals(500));
      expect(result.items.first.qty, equals(5));

      expect(repository.sales['sale-update-1']?.total, equals(500));
    });

    test('throws SaleNotFoundException when sale does not exist', () async {
      final sale = Sale(
        id: 'unknown-sale',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 500,
        items: [],
        source: 'MANUAL',
        status: 'COMPLETED',
      );

      expect(() => updateSale(sale), throwsA(isA<SaleNotFoundException>()));
    });

    test(
      'throws AlreadyCancelledException when updating cancelled sale',
      () async {
        final sale = Sale(
          id: 'sale-cancelled',
          dateTime: DateTime(2026, 3, 1, 10),
          createdAt: DateTime(2026, 3, 1, 10),
          total: 300,
          items: [],
          source: 'MANUAL',
          status: 'COMPLETED',
        );

        await recordSale(sale);
        await cancelSale('sale-cancelled');

        final updatedSale = Sale(
          id: 'sale-cancelled',
          dateTime: DateTime(2026, 3, 1, 11),
          createdAt: DateTime(2026, 3, 1, 10),
          total: 500,
          items: [],
          source: 'MANUAL',
          status: 'COMPLETED',
        );

        expect(
          () => updateSale(updatedSale),
          throwsA(isA<AlreadyCancelledException>()),
        );
      },
    );
  });

  group('CancelSale use case', () {
    test('marks an existing sale as cancelled and sets cancelledAt', () async {
      final sale = Sale(
        id: 'sale-1',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 300,
        items: [
          SaleItem(productId: 'sucre', name: 'Sucre', qty: 3, unitPrice: 100),
        ],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      await recordSale(sale);

      final cancelled = await cancelSale('sale-1');

      expect(cancelled.id, equals('sale-1'));
      expect(cancelled.status, equals('CANCELLED'));
      expect(cancelled.cancelledAt, isNotNull);
      expect(repository.sales['sale-1']?.status, equals('CANCELLED'));
    });

    test('throws SaleNotFoundException when sale does not exist', () async {
      expect(
        () => cancelSale('unknown-sale'),
        throwsA(isA<SaleNotFoundException>()),
      );
    });

    test('throws AlreadyCancelledException when cancelling twice', () async {
      final sale = Sale(
        id: 'sale-2',
        dateTime: DateTime(2026, 3, 1, 10),
        createdAt: DateTime(2026, 3, 1, 10),
        total: 300,
        items: [],
        source: 'VOICE',
        status: 'COMPLETED',
      );

      await recordSale(sale);
      await cancelSale('sale-2');

      expect(
        () => cancelSale('sale-2'),
        throwsA(isA<AlreadyCancelledException>()),
      );
    });
  });
}
