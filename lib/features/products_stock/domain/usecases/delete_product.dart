import '../repositories/product_repository.dart';

class DeleteProduct {
  const DeleteProduct(this._repository);

  final ProductRepository _repository;

  Future<void> call(String productId) {
    if (productId.isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        "Impossible de supprimer une fiche sans identifiant",
      );
    }
    return _repository.deleteProduct(productId);
  }
}
