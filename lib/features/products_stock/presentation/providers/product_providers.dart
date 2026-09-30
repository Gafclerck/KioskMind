import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/create_product.dart';

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

class ProductActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> create(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(createProductProvider)(product),
    );
    return !state.hasError;
  }
}

final productActionsProvider =
    NotifierProvider<ProductActionsNotifier, AsyncValue<void>>(
      ProductActionsNotifier.new,
    );
