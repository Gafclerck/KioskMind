import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import 'edit_product_page.dart';
import 'product_detail_page.dart';
import 'record_stock_movement_page.dart';

/// Route `/product/:id`, résolue depuis le flux [productsProvider].
///
/// Le payload FCM ne porte que `productId`, pas l'entier `Product` :
/// on le retombe sur le flux plutôt que sur `state.extra`, qui serait
/// périmé dès que le stock change.
class ProductDetailRoute extends ConsumerWidget {
  const ProductDetailRoute({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Product>> produits = ref.watch(productsProvider);

    final Product? produit = produits.valueOrNull
        ?.where((p) => p.id == productId)
        .firstOrNull;

    if (produit == null) {
      // Chargement en cours ou produit supprimé.
      return Scaffold(
        appBar: AppBar(title: const Text('Fiche Produit')),
        body: Center(
          child: produits.valueOrNull == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Produit introuvable — il a peut-être été supprimé.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    return ProductDetailPage(
      product: produit,
      onEdit: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EditProductPage(product: produit),
        ),
      ),
      onRecordMovement: (direction) =>
          Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => RecordStockMovementPage(
                product: produit,
                initialDirection: direction,
              ),
            ),
          ),
    );
  }
}
