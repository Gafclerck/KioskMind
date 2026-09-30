import '../entities/sale.dart';

abstract class SalesRepository {
  Future<void> recordSale(Sale sale);

  Future<List<Sale>> getSalesHistory({
    required String shopId,
  });

  Future<List<Sale>> getSalesByDateRange({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  });
}