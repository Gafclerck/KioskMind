import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products_stock/domain/entities/product.dart';
import '../../../products_stock/presentation/providers/product_providers.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/providers/sales_provider.dart';

/// Instantané des ventes pour le profil. Réutilise le usecase [GetSalesHistory]
/// existant : aucune nouvelle source de données, aucune duplication du calcul.
final profileSalesSnapshotProvider = FutureProvider.autoDispose<List<Sale>>((
  ref,
) {
  return ref.watch(getSalesHistoryProvider)();
});

class ProfileStats {
  const ProfileStats({required this.salesCount, required this.activeProducts});

  final int salesCount;
  final int activeProducts;
}

/// Statistiques affichées dans l'en-tête du profil, dérivées des providers
/// de ventes et de produits déjà existants.
final profileStatsProvider = Provider<ProfileStats>((ref) {
  final int salesCount =
      ref.watch(profileSalesSnapshotProvider).valueOrNull?.length ?? 0;
  final List<Product>? products = ref.watch(productsProvider).valueOrNull;
  final int activeProducts = products?.length ?? 0;
  return ProfileStats(salesCount: salesCount, activeProducts: activeProducts);
});
