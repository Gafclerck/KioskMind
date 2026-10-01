import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/product_options.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/feedback_dialogs.dart';
import '../widgets/product_card.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart';
import 'product_detail_page.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  void _openAddProduct(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddProductPage()));
  }

  Future<void> _openEditProduct(BuildContext context, Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditProductPage(product: product),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          onEdit: () => _openEditProduct(context, product),
          onRestock: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réapprovisionnement à venir')),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDeleteConfirmation(
      context,
      productName: product.name,
    );
    if (!confirmed || !context.mounted) return;

    final deleted = await ref
        .read(productActionsProvider.notifier)
        .delete(product.id);
    if (!context.mounted) return;

    if (!deleted) {
      await showErrorDialog(
        context,
        title: 'Erreur de suppression',
        message:
            'Impossible de supprimer ce produit. Vérifiez votre connexion internet.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(filteredProductsProvider);
    final activeCategory = ref.watch(productFilterProvider);
    final query = ref.watch(productSearchProvider);
    final hasProducts =
        ref.watch(productsProvider).valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Stock')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddProduct(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) =>
                  ref.read(productSearchProvider.notifier).update(value),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () =>
                            ref.read(productSearchProvider.notifier).clear(),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Tous',
                  isSelected: activeCategory == null,
                  onSelected: () =>
                      ref.read(productFilterProvider.notifier).select(null),
                ),
                for (final category in productCategories)
                  _CategoryChip(
                    label: category,
                    isSelected: activeCategory == category,
                    onSelected: () => ref
                        .read(productFilterProvider.notifier)
                        .select(category),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _MessageView(
                title: 'Erreur de connexion',
                message:
                    'Impossible de synchroniser. Vérifiez votre connexion internet.',
                actionLabel: 'Réessayer',
                onAction: () => ref.invalidate(productsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _MessageView(
                    title: hasProducts ? 'Aucun résultat' : 'Aucun produit',
                    message: hasProducts
                        ? 'Aucun produit ne correspond à votre recherche.'
                        : 'Ajoutez votre premier produit pour commencer à gérer votre stock.',
                    actionLabel: hasProducts ? null : 'Ajouter un produit',
                    onAction: hasProducts
                        ? null
                        : () => _openAddProduct(context),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final product = list[index];
                    return ProductCard(
                      key: ValueKey<String>(product.id),
                      product: product,
                      onEdit: () => _openEditProduct(context, product),
                      onEditQuantity: () => _openDetail(context, product),
                      onOpenDetail: () => _openDetail(context, product),
                      onDelete: () => _deleteProduct(context, ref, product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
