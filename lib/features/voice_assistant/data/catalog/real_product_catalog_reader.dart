import '../../../../features/products_stock/domain/entities/product.dart';
import '../../../../features/products_stock/domain/repositories/product_repository.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/ports/product_catalog_reader.dart';

import 'product_alias_generator.dart';

/// Real adapter implementing [ProductCatalogReader] backed by [ProductRepository].
///
/// Converts domain [Product] entities to [ProductSnapshot] value objects so the
/// voice resolution pipeline, vocabulary biasing and stock queries reflect the
/// merchant's real stock catalog.
final class RealProductCatalogReader implements ProductCatalogReader {
  RealProductCatalogReader(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<ProductSnapshot>> readActiveProducts() async {
    final List<Product> products = await _repository.getProducts();
    return products.map(toSnapshot).toList();
  }

  @override
  Future<List<ProductSnapshot>> readAllProducts() async {
    final List<Product> products = await _repository.getProducts();
    return products.map(toSnapshot).toList();
  }

  @override
  Future<ProductSnapshot?> findById(String productId) async {
    final Product? product = await _repository.getProductById(productId);
    return product != null ? toSnapshot(product) : null;
  }

  /// Converts a business [Product] to a voice [ProductSnapshot].
  static ProductSnapshot toSnapshot(Product product) {
    return ProductSnapshot(
      id: product.id,
      name: product.name,
      aliases: ProductAliasGenerator.generate(product.name),
      unit: product.unit,
      price: product.salePrice.toDouble(),
      purchasePrice: product.purchasePrice.toDouble(),
      stock: product.quantity.toDouble(),
      alertThreshold: product.alertThreshold.toDouble(),
      averageDailyQty: 0,
      isArchived: false,
    );
  }
}
