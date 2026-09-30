import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class GetSalesHistory {
  final SalesRepository repository;

  GetSalesHistory(this.repository);

  Future<List<Sale>> call(String shopId) {
    return repository.getSalesHistory(
      shopId: shopId,
    );
  }
}