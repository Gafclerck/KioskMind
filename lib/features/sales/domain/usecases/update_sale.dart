import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class UpdateSale {
  final SalesRepository repository;

  UpdateSale(this.repository);

  Future<Sale> call(Sale sale) async {
    return await repository.updateSale(sale);
  }
}