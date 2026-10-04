import 'package:csv/csv.dart';

import '../../../products_stock/domain/entities/product.dart';
import '../../../sales/domain/entities/sale.dart';

/// Construit le contenu CSV (texte) des ventes et du stock.
///
/// Séparateur `;` (convention française) et virgule décimale, compatible
/// Excel et LibreOffice. Chaque ligne d'article = une ligne de ventes.
class SalesCsvBuilder {
  const SalesCsvBuilder();

  String build({required List<Sale> sales, required List<Product> products}) {
    final List<List<dynamic>> rows = <List<dynamic>>[];

    rows.add(<String>[
      'Date',
      'Produit',
      'Quantite',
      'PU',
      'Sous-total',
      'Total vente',
      'Source',
      'Statut',
    ]);
    for (final Sale sale in sales) {
      for (final SaleItem item in sale.items) {
        rows.add(<Object>[
          _formatDateTime(sale.dateTime),
          item.name,
          _number(item.qty),
          _number(item.unitPrice),
          _number(item.qty * item.unitPrice),
          _number(sale.total),
          sale.source,
          _statusLabel(sale.status),
        ]);
      }
    }

    rows.add(const <String>['']);
    rows.add(const <String>['PRODUITS']);
    rows.add(const <String>[
      'Nom',
      'Categorie',
      'Quantite',
      'Prix achat',
      'Prix vente',
      'Marge',
    ]);
    for (final Product product in products) {
      rows.add(<Object>[
        product.name,
        product.category,
        product.quantity,
        product.purchasePrice,
        product.salePrice,
        product.margin,
      ]);
    }

    return const CsvEncoder(
      fieldDelimiter: ';',
      lineDelimiter: '\n',
      addBom: true,
    ).convert(rows);
  }

  String _formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _number(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _statusLabel(String status) {
    return switch (status) {
      'completed' => 'Payee',
      'cancelled' => 'Annulee',
      'refunded' => 'Remboursee',
      _ => status,
    };
  }
}
