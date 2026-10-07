import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../providers/product_providers.dart';
import '../widgets/formatters.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import 'record_stock_movement_page.dart';

/// Fiche produit détaillée : marge, niveau de stock, historique et actions.
///
/// Le design prévoit aussi une carte « Prédiction IA KioskMind » et un graphe des
/// ventes sur 7 jours. La prédiction dépend d'un modèle qui n'existe pas encore,
/// elle est donc absente ici.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onRecordMovement,
  });

  final Product product;
  final VoidCallback onEdit;
  final void Function(StockMovementDirection direction) onRecordMovement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = formatUnit(product.quantity, product.unit);
    final movements = ref.watch(stockMovementsProvider(product.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche Produit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(
                name: product.name,
                imageUrl: product.imageUrl,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Catégorie: ${product.category}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${product.quantity}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: product.alertLevel.needsAttention
                                ? scheme.error
                                : null,
                          ),
                        ),
                        Text(
                          '/${product.alertThreshold} $unit',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StockAlertBadge(level: product.alertLevel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PriceTile(
                  label: 'Prix Achat',
                  value: formatCfa(product.purchasePrice),
                ),
              ),
              Expanded(
                child: _PriceTile(
                  label: 'Prix Vente',
                  value: formatCfa(product.salePrice),
                ),
              ),
              Expanded(
                child: _PriceTile(
                  label: 'Marge Net',
                  value: '+${formatCfa(product.margin)}',
                  isProfit: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: scheme.primary),
              title: const Text('Seuil d\'alerte'),
              subtitle: Text(
                'Alerter quand le stock est inférieur à '
                '${product.alertThreshold} $unit',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mouvements de stock',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          movements.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Impossible de charger l'historique."),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Aucun mouvement enregistré.'),
                );
              }
              return Column(
                children: [
                  for (final movement in list.take(5))
                    _MovementTile(movement: movement, unit: product.unit),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier Fiche'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      onRecordMovement(StockMovementDirection.inbound),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Réapprovisionner'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  onRecordMovement(StockMovementDirection.outbound),
              icon: Icon(Icons.remove_shopping_cart, color: scheme.error),
              label: Text(
                'Sortie manuelle',
                style: TextStyle(color: scheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.unit});

  final StockMovement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isInbound = movement.type.isInbound;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isInbound ? Icons.arrow_downward : Icons.arrow_upward,
        color: isInbound ? scheme.primary : scheme.error,
      ),
      title: Text(_reasonLabel(movement.reason)),
      subtitle: Text(
        movement.note == null
            ? _formatDate(movement.createdAt)
            : '${movement.note} - ${_formatDate(movement.createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${movement.impactLabel} ${formatUnit(movement.quantity, unit)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isInbound ? scheme.primary : scheme.error,
        ),
      ),
    );
  }

  static String _reasonLabel(StockMovementReason reason) => switch (reason) {
    StockMovementReason.purchase => 'Achat fournisseur',
    StockMovementReason.sale => 'Vente',
    StockMovementReason.loss => 'Perte',
    StockMovementReason.breakage => 'Casse',
    StockMovementReason.donation => 'Don',
    StockMovementReason.manualAdjustment => 'Ajustement manuel',
  };

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({
    required this.label,
    required this.value,
    this.isProfit = false,
  });

  final String label;
  final String value;
  final bool isProfit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isProfit ? scheme.primary : null,
          ),
        ),
      ],
    );
  }
}
