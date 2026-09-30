import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/create_product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  // TEMPORAIRE : à remplacer par le provider d'utilisateur de l'Epic 1.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Aucun utilisateur connecté');

  return ProductRepositoryImpl(
    firestore: FirebaseFirestore.instance,
    userId: uid,
  );
});

final createProductProvider = Provider<CreateProduct>((ref) {
  return CreateProduct(ref.watch(productRepositoryProvider));
});

class ProductActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null); // au repos

  /// Retourne true si la création a réussi.
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