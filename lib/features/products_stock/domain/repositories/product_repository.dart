import '../entities/product.dart';

abstract interface class ProductRepository {
  Future<void> createProduct(Product product);

  Future<void> updateProduct(Product product);

  Future<void> deleteProduct(String productId);

  Stream<List<Product>> watchProducts();
}
