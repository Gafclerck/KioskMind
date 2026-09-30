import '../entities/product.dart';

abstract interface class ProductRepository {
  Future<void> createProduct(Product product);
}