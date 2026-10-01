import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLowStock = product.quantity <= product.alertThreshold;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            product.name.characters.first.toUpperCase(),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        title: Text(product.name),
        subtitle: Text('${product.salePrice} F / ${product.unit}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${product.quantity} ${product.unit}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLowStock ? scheme.error : null,
              ),
            ),
            PopupMenuButton<_ProductAction>(
              tooltip: 'Actions',
              onSelected: (_ProductAction action) {
                switch (action) {
                  case _ProductAction.edit:
                    onEdit();
                  case _ProductAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ProductAction>(
                  value: _ProductAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<_ProductAction>(
                  value: _ProductAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProductAction { edit, delete }
