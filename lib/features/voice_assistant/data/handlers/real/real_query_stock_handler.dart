import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real handler for the stock query intent. Read only: it never writes.
final class RealQueryStockHandler implements QueryStockHandler {
  RealQueryStockHandler(this._catalog);

  final ProductCatalogReader _catalog;

  @override
  String get intentId => 'query_stock';

  @override
  Future<Result<QueryStockResult>> execute(
    CommandContext context,
    QueryStockInput input,
  ) async {
    final ProductSnapshot? product = await _catalog.findById(input.productId);
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
