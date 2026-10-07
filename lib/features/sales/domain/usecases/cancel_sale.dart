import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class CancelSale {
  final SalesRepository repository;

  CancelSale(this.repository);

  Future<Sale> call(String saleId) async {
    return repository.cancelSale(saleId);
  }
}
