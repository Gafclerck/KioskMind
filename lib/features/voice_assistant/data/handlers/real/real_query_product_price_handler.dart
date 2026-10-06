import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real handler for querying product selling and purchase prices.
final class RealQueryProductPriceHandler implements QueryProductPriceHandler {
  RealQueryProductPriceHandler(this._catalogReader);

  final ProductCatalogReader _catalogReader;

  @override
  String get intentId => 'query_product_price';

  @override
  Future<Result<QueryProductPriceResult>> execute(
    CommandContext context,
    QueryProductPriceInput input,
  ) async {
    final ProductSnapshot? product = await _catalogReader.findById(
      input.productId,
    );

    if (product == null) {
      return Failed<QueryProductPriceResult>(
        UnknownProduct(productId: input.productId),
      );
    }

    if (product.isArchived) {
      return Failed<QueryProductPriceResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }

    return Success<QueryProductPriceResult>((
      productId: product.id,
      productName: product.name,
      price: product.price,
      purchasePrice: product.purchasePrice,
      unit: product.unit,
    ));
  }
}
