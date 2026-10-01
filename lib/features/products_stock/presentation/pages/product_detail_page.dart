import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../widgets/formatters.dart';
import '../widgets/product_card.dart';

/// Fiche produit détaillée : marge, niveau de stock et actions.
///
/// Le design prévoit aussi une carte « Prédiction IA KioskMind » et un graphe des
/// ventes sur 7 jours. Ces deux blocs dépendent respectively de l'historique des
/// ventes (UC7/UC8) et d'un modèle de prédiction, ils sont donc absents ici.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onRestock,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = formatUnit(product.quantity, product.unit);

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche Produit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  product.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                  onPressed: onRestock,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Réapprovisionner'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
