import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class RecordSale {
  final SalesRepository repository;

  RecordSale(this.repository);

  Future<void> call(Sale sale) {
    return repository.recordSale(sale);
  }
}