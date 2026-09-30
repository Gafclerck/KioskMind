import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text('${product.salePrice} F / ${product.unit}'),
        trailing: Text('${product.quantity} ${product.unit}'),
      ),
    );
  }
}
