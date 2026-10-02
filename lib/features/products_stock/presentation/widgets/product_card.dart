import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onEditQuantity,
    required this.onDelete,
    required this.onOpenDetail,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onEditQuantity;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = product.alertLevel;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      product.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_formatPrice(product.salePrice)} / ${product.unit}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${product.quantity} ${_unitLabel(product)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StockAlertBadge(level: level),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Seuil d\'alerte : ${product.alertThreshold} ${_unitLabel(product)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onEditQuantity,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Modifier Qte'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onOpenDetail,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Détails'),
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    tooltip: 'Modifier la fiche',
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _unitLabel(Product p) {
    final unit = p.unit.toLowerCase();
    return unit.endsWith('s') ? unit : '${unit}s';
  }

  String _formatPrice(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${buffer.toString()} F';
  }
}

/// Badge d'état du stock, partagé par la carte et la fiche produit.
class StockAlertBadge extends StatelessWidget {
  const StockAlertBadge({super.key, required this.level});

  final StockAlertLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (level) {
      StockAlertLevel.outOfStock || StockAlertLevel.rupture => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      StockAlertLevel.critical => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      StockAlertLevel.ok => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
