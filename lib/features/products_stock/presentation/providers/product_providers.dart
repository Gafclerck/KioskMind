import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/update_product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Aucun utilisateur connecté');

  return ProductRepositoryImpl(
    firestore: FirebaseFirestore.instance,
    userId: uid,
  );
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchProducts();
});

final createProductProvider = Provider<CreateProduct>((ref) {
  return CreateProduct(ref.watch(productRepositoryProvider));
});

final updateProductProvider = Provider<UpdateProduct>((ref) {
  return UpdateProduct(ref.watch(productRepositoryProvider));
});

final deleteProductProvider = Provider<DeleteProduct>((ref) {
  return DeleteProduct(ref.watch(productRepositoryProvider));
});

class ProductActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  Future<bool> create(Product product) {
    return _run(() => ref.read(createProductProvider)(product));
  }

  Future<bool> update(Product product) {
    return _run(() => ref.read(updateProductProvider)(product));
  }

  Future<bool> delete(String productId) {
    return _run(() => ref.read(deleteProductProvider)(productId));
  }
}

final productActionsProvider =
    NotifierProvider<ProductActionsNotifier, AsyncValue<void>>(
      ProductActionsNotifier.new,
    );
