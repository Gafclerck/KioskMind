import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _products = firestore
           .collection('users')
           .doc(userId)
           .collection('products');

  final CollectionReference<Map<String, dynamic>> _products;

  @override
  Future<void> createProduct(Product product) {
    return _products.doc().set(ProductModel.toFirestore(product));
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _products
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}
