import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:kiosk_mind/features/sales/data/models/sale_model.dart';
import 'package:kiosk_mind/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';

final class _MockRemoteDataSource implements SalesRemoteDataSource {
  SaleModel? recordedSale;
  String? cancelledSaleId;
  List<SaleModel> historyToReturn = [];

  @override
  Future<SaleModel> recordSale(SaleModel sale) async {
    recordedSale = sale;
    return sale;
  }

  @override
  Future<SaleModel> cancelSale(String saleId) async {
    cancelledSaleId = saleId;
    return SaleModel(
      id: saleId,
      dateTime: DateTime(2026, 3, 1),
      createdAt: DateTime(2026, 3, 1),
      total: 100,
      items: [],
      source: 'VOICE',
      status: 'CANCELLED',
      cancelledAt: DateTime(2026, 3, 1),
    );
  }

  @override
  Future<List<SaleModel>> getSalesHistory() async {
    return historyToReturn;
  }

  @override
  Future<List<SaleModel>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return historyToReturn;
  }
}

void main() {
  late _MockRemoteDataSource remote;
  late SalesRepositoryImpl repository;

  setUp(() {
    remote = _MockRemoteDataSource();
    repository = SalesRepositoryImpl(remote);
  });

  test('recordSale forwards SaleModel and returns recorded sale', () async {
    final sale = Sale(
      id: 'cmd-99',
      dateTime: DateTime(2026, 3, 1, 10),
      createdAt: DateTime(2026, 3, 1, 10),
      total: 450,
      items: [SaleItem(productId: 'riz', name: 'Riz', qty: 1, unitPrice: 450)],
      source: 'VOICE',
      status: 'COMPLETED',
    );

    final result = await repository.recordSale(sale);

    expect(result.id, equals('cmd-99'));
    expect(remote.recordedSale?.id, equals('cmd-99'));
    expect(remote.recordedSale?.total, equals(450));
  });

  test(
    'cancelSale forwards saleId to remote and returns cancelled sale',
    () async {
      final result = await repository.cancelSale('sale-77');

      expect(result.id, equals('sale-77'));
      expect(result.status, equals('CANCELLED'));
      expect(remote.cancelledSaleId, equals('sale-77'));
    },
  );

  test('getSalesHistory forwards to remoteDataSource', () async {
    final item = SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 3, 1),
      createdAt: DateTime(2026, 3, 1),
      total: 100,
      items: [],
      source: 'VOICE',
      status: 'COMPLETED',
    );
    remote.historyToReturn = [item];

    final history = await repository.getSalesHistory();

    expect(history.length, equals(1));
    expect(history.first.id, equals('sale-1'));
  });
}
