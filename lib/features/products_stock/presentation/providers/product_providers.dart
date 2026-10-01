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

/// Catégorie active dans les onglets de filtre. [null] signifie « Tous ».
class ProductFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? category) => state = category;
}

final productFilterProvider = NotifierProvider<ProductFilterNotifier, String?>(
  ProductFilterNotifier.new,
);

/// Recherche texte + catégorie, appliqués à la liste affichée.
final productSearchProvider = NotifierProvider<ProductSearchNotifier, String>(
  ProductSearchNotifier.new,
);

class ProductSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

/// Liste filtrée consommée par l'écran Mon Stock.
///
/// Séparée de [productsProvider] volontairement : le flux brut reste la source
/// de vérité, la vue filtrée est recalculée à chaque frappe.
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  final category = ref.watch(productFilterProvider);
  final query = ref.watch(productSearchProvider).trim().toLowerCase();

  return products.whenData(
    (list) => list.where((product) {
      final matchesCategory = category == null || product.category == category;
      final matchesQuery =
          query.isEmpty || product.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList(),
  );
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
