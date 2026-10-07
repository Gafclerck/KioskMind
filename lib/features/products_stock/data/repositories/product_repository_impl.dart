import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/product_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

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
    final docRef = product.id.isNotEmpty
        ? _products.doc(product.id)
        : _products.doc();
    return docRef.set(ProductModel.toFirestore(product));
  }

  @override
  Future<void> updateProduct(Product product) {
    return _products.doc(product.id).set(ProductModel.toFirestore(product));
  }

  @override
  Future<void> deleteProduct(String productId) {
    return _products.doc(productId).delete();
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

  @override
  Future<List<Product>> getProducts() async {
    final snapshot = await _products.orderBy('name').get();
    return snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<Product?> getProductById(String productId) async {
    final doc = await _products.doc(productId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ProductModel.fromFirestore(doc.id, doc.data()!);
  }
}
