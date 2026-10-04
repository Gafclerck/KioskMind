import '../entities/product.dart';
import '../repositories/product_repository.dart';

class UpdateProduct {
  const UpdateProduct(this._repository);

  final ProductRepository _repository;

  /// [product.id] doit correspondre à un document existant : une fiche sans id
  /// est rejetée ici plutôt que d'écrire un document orphelin côté Firestore.
  Future<void> call(Product product) {
    if (product.id.isEmpty) {
      throw ArgumentError.value(
        product.id,
        'product.id',
        "Impossible de modifier une fiche sans identifiant",
      );
    }
    return _repository.updateProduct(product);
  }
}
