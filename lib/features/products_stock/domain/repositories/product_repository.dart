import '../entities/product.dart';

abstract interface class ProductRepository {
  Future<void> createProduct(Product product);

  Stream<List<Product>> watchProducts();
}
