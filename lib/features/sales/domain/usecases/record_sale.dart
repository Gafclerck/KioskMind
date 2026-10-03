import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class RecordSale {
  final SalesRepository repository;

  RecordSale(this.repository);

  Future<Sale> call(Sale sale) async {
    return repository.recordSale(sale);
  }
}
