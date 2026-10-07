import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../catalog/in_memory_product_catalog.dart';

/// Mock of the stock consultation. Read only: it never writes.
final class MockQueryStockHandler implements QueryStockHandler {
  MockQueryStockHandler(this._catalog);

  final InMemoryProductCatalog _catalog;

  @override
  String get intentId => 'query_stock';

  @override
  Future<Result<QueryStockResult>> execute(
    CommandContext context,
    QueryStockInput input,
  ) async {
    final ProductSnapshot? product = _catalog.productById(input.productId);
    if (product == null) {
      return Failed<QueryStockResult>(
        UnknownProduct(productId: input.productId),
      );
    }
    if (product.isArchived) {
      return Failed<QueryStockResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }
    return Success<QueryStockResult>((
      productId: product.id,
      productName: product.name,
      stock: product.stock,
      unit: product.unit,
      alertThreshold: product.alertThreshold,
    ));
  }
}
