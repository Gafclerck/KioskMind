import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/stock_movement_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/stock_state.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/stock_movement_repository.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/record_stock_movement.dart';
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

/// Niveau d'alerte filtré, pour l'onglet « Rupture de Stock » du design.
class StockAlertFilterNotifier extends Notifier<StockAlertLevel?> {
  @override
  StockAlertLevel? build() => null;

  void select(StockAlertLevel? level) => state = level;
}

final stockAlertFilterProvider =
    NotifierProvider<StockAlertFilterNotifier, StockAlertLevel?>(
      StockAlertFilterNotifier.new,
    );

/// Produits de la liste filtrée intersectés avec le filtre d'alerte.
final alertedProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(filteredProductsProvider);
  final level = ref.watch(stockAlertFilterProvider);

  if (level == null) return products;

  return products.whenData(
    (list) => list.where((product) => product.alertLevel == level).toList(),
  );
});

/// Vue par produit de l'état du stock, pour UC9.
final stockStatesProvider = Provider<AsyncValue<List<StockState>>>((ref) {
  final products = ref.watch(productsProvider);

  return products.whenData(
    (list) => list
        .map(
          (product) => StockState(
            productId: product.id,
            productName: product.name,
            quantity: product.quantity,
            alertThreshold: product.alertThreshold,
            level: product.alertLevel,
            lastMovementAt: null,
          ),
        )
        .toList(),
  );
});

/// Compteurs et valeur du stock pour l'écran d'accueil et les badges.
final stockOverviewProvider = Provider<AsyncValue<StockOverview>>((ref) {
  final products = ref.watch(productsProvider);

  return products.whenData((list) {
    if (list.isEmpty) return StockOverview.empty;

    var outOfStock = 0;
    var rupture = 0;
    var critical = 0;
    var totalUnits = 0;
    var stockValue = 0;

    for (final product in list) {
      totalUnits += product.quantity;
      stockValue += product.quantity * product.purchasePrice;
      switch (product.alertLevel) {
        case StockAlertLevel.outOfStock:
          outOfStock++;
        case StockAlertLevel.rupture:
          rupture++;
        case StockAlertLevel.critical:
          critical++;
        case StockAlertLevel.ok:
          break;
      }
    }

    return StockOverview(
      totalProducts: list.length,
      totalUnits: totalUnits,
      outOfStock: outOfStock,
      rupture: rupture,
      critical: critical,
      stockValue: stockValue,
    );
  });
});

final stockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>(
      (ref, productId) =>
          ref.watch(stockMovementRepositoryProvider).watchMovements(productId),
    );

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((
  ref,
) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Aucun utilisateur connecté');

  return StockMovementRepositoryImpl(
    firestore: FirebaseFirestore.instance,
    userId: uid,
  );
});

final recordStockInProvider = Provider<RecordStockIn>((ref) {
  return RecordStockIn(ref.watch(stockMovementRepositoryProvider));
});

final recordStockOutProvider = Provider<RecordStockOut>((ref) {
  return RecordStockOut(ref.watch(stockMovementRepositoryProvider));
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

class StockMovementActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  /// UC7 : entrée de stock, achat ou réapprovisionnement.
  Future<bool> recordIn(StockMovement movement) {
    return _run(() => ref.read(recordStockInProvider)(movement));
  }

  /// UC8 : sortie manuelle, perte, casse ou don.
  Future<bool> recordOut(StockMovement movement) {
    return _run(() => ref.read(recordStockOutProvider)(movement));
  }
}

final stockMovementActionsProvider =
    NotifierProvider<StockMovementActionsNotifier, AsyncValue<void>>(
      StockMovementActionsNotifier.new,
    );
