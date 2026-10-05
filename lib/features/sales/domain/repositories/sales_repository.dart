import '../entities/sale.dart';

abstract class SalesRepository {
  Future<Sale> recordSale(Sale sale);

  Future<Sale> updateSale(Sale sale);

  Future<Sale> cancelSale(String saleId);

  Future<List<Sale>> getSalesHistory();

  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });
}
