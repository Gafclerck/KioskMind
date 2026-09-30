import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class GetSalesDashboard {
  final SalesRepository repository;

  GetSalesDashboard(this.repository);

  Future<List<Sale>> call({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return repository.getSalesByDateRange(
      shopId: shopId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}