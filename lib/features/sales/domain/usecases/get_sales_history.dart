import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class GetSalesHistory {
  final SalesRepository repository;

  GetSalesHistory(this.repository);

  Future<List<Sale>> call() async {
    return await repository.getSalesHistory();
  }
}