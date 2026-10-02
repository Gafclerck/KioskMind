import '../entities/sale.dart';

abstract class SalesRepository {
  Future<void> recordSale(Sale sale);

  Future<List<Sale>> getSalesHistory();

  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });
}