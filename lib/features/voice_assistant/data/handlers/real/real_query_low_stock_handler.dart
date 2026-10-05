import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real handler querying low stock and stock ruptures.
final class RealQueryLowStockHandler implements QueryLowStockHandler {
  RealQueryLowStockHandler(this._catalogReader);

  final ProductCatalogReader _catalogReader;

  @override
  String get intentId => 'query_low_stock';

  @override
  Future<Result<QueryLowStockResult>> execute(
    CommandContext context,
    QueryLowStockInput input,
  ) async {
    final List<ProductSnapshot> products = await _catalogReader
        .readActiveProducts();

    final List<LowStockItemResult> lowStockItems = <LowStockItemResult>[];

    for (final ProductSnapshot product in products) {
      final double stock = product.stock;
      final double threshold = product.alertThreshold;

      final bool isOut = stock <= 0;
      final bool isCritical = stock <= threshold;

      if (!isCritical) {
        continue;
      }

      final String levelStr = isOut ? 'out_of_stock' : 'rupture';

      if (input.level == 'out_of_stock' && !isOut) {
        continue;
      }

      lowStockItems.add((
        productId: product.id,
        name: product.name,
        stock: stock,
        unit: product.unit,
        alertThreshold: threshold,
        alertLevel: levelStr,
      ));
    }

    return Success<QueryLowStockResult>((products: lowStockItems));
  }
}
