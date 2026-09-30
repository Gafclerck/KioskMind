import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_data_source.dart';
import '../models/sale_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  final SalesRemoteDataSource remoteDataSource;

  SalesRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> recordSale(Sale sale) async {
    final saleModel = SaleModel(
      dateTime: sale.dateTime,
      createdAt: sale.createdAt,
      total: sale.total,
      items: sale.items,
      source: sale.source,
      status: sale.status,
      cancelledAt: sale.cancelledAt,
    );

    await remoteDataSource.recordSale(saleModel);
  }

  @override
  Future<List<Sale>> getSalesHistory() async {
    return await remoteDataSource.getSalesHistory();
  }

  @override
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await remoteDataSource.getSalesByDateRange(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
