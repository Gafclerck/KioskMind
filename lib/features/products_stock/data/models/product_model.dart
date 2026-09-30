import '../../domain/entities/product.dart';

abstract final class ProductModel {
  /// Le [id] vient du document Firestore, pas de ses données.
  static Product fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] as String,
      imageUrl: data['imageUrl'] as String?,
      category: data['category'] as String,
      unit: data['unit'] as String,
      purchasePrice: (data['purchasePrice'] as num).toInt(),
      salePrice: (data['salePrice'] as num).toInt(),
      quantity: (data['quantity'] as num).toInt(),
      alertThreshold: (data['alertThreshold'] as num).toInt(),
    );
  }

  static Map<String, dynamic> toFirestore(Product product) => {
        'name': product.name,
        'imageUrl': product.imageUrl,
        'category': product.category,
        'unit': product.unit,
        'purchasePrice': product.purchasePrice,
        'salePrice': product.salePrice,
        'quantity': product.quantity,
        'alertThreshold': product.alertThreshold,
      };
}