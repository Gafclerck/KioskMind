import '../../../../../core/usecase/result.dart';
import '../../../../sales/domain/entities/sale.dart';
import '../../../../sales/domain/usecases/get_sales_history.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real handler for querying business overview information.
final class RealQueryBusinessInfoHandler implements QueryBusinessInfoHandler {
  RealQueryBusinessInfoHandler({
    required this.catalogReader,
    required this.getSalesHistory,
    this.storeName = 'KioskMind',
  });

  final ProductCatalogReader catalogReader;
  final GetSalesHistory getSalesHistory;
  final String storeName;

  @override
  String get intentId => 'query_business_info';

  @override
  Future<Result<QueryBusinessInfoResult>> execute(
    CommandContext context,
    QueryBusinessInfoInput input,
  ) async {
    final List<ProductSnapshot> products = await catalogReader
        .readActiveProducts();
    final List<Sale> sales = await getSalesHistory();

    return Success<QueryBusinessInfoResult>((
      storeName: storeName,
      activeProductsCount: products.length,
      totalSalesCount: sales.length,
    ));
  }
}
