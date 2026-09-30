import '../entities/product_snapshot.dart';

/// Read access to the product catalog, as the voice module needs it.
///
/// The resolver resolves a spoken name to a product identifier through this
/// port, never through an identifier invented by a language model (D5).
abstract interface class ProductCatalogReader {
  /// Products that can still be sold, archived ones excluded.
  Future<List<ProductSnapshot>> readActiveProducts();

  /// Returns the product whatever its archived flag: telling an archived
  /// product from an unknown one is the caller's decision, not this port's.
  Future<ProductSnapshot?> findById(String productId);
}
