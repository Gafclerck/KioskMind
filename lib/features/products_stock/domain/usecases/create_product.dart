import '../entities/product.dart';
import '../repositories/product_repository.dart';

class CreateProduct {
  const CreateProduct(this._repository);

  final ProductRepository _repository;

  Future<void> call(Product product) => _repository.createProduct(product);
}