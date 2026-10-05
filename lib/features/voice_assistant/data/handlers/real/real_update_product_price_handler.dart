import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../products_stock/domain/entities/product.dart';
import '../../../../products_stock/domain/repositories/product_repository.dart';
import '../../../../products_stock/domain/usecases/update_product.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real handler for updating product selling price.
final class RealUpdateProductPriceHandler implements UpdateProductPriceHandler {
  RealUpdateProductPriceHandler({
    required this.updateProduct,
    required this.productRepository,
    required this.catalogReader,
  });

  final UpdateProduct updateProduct;
  final ProductRepository productRepository;
  final ProductCatalogReader catalogReader;

  @override
  String get intentId => 'update_product_price';

  @override
  Future<Result<UpdateProductPriceResult>> execute(
    CommandContext context,
    UpdateProductPriceInput input,
  ) async {
    final ProductSnapshot? snapshot = await catalogReader.findById(
      input.productId,
    );
    if (snapshot == null) {
      return Failed<UpdateProductPriceResult>(
        UnknownProduct(productId: input.productId),
      );
    }

    if (snapshot.isArchived) {
      return Failed<UpdateProductPriceResult>(
        ArchivedProduct(productId: snapshot.id, productName: snapshot.name),
      );
    }

    if (input.newPrice <= 0) {
      return Failed<UpdateProductPriceResult>(
        InvalidQuantity(productId: snapshot.id, qty: input.newPrice),
      );
    }

    final Product? current = await productRepository.getProductById(
      input.productId,
    );
    if (current == null) {
      return Failed<UpdateProductPriceResult>(
        UnknownProduct(productId: input.productId, productName: snapshot.name),
      );
    }

    final Product updated = current.copyWith(salePrice: input.newPrice.toInt());

    await updateProduct(updated);

    return Success<UpdateProductPriceResult>((
      productId: current.id,
      productName: current.name,
      oldPrice: snapshot.price,
      newPrice: input.newPrice,
    ));
  }
}
