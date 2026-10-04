import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/export_reporting/data/builders/sales_csv_builder.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';

void main() {
  test('builds a sales CSV with the French conventional separator', () {
    final Sale sale = Sale(
      id: 's1',
      dateTime: DateTime(2026, 5, 12, 14, 30),
      createdAt: DateTime(2026, 5, 12, 14, 30),
      total: 375.0,
      source: 'kiosk',
      status: 'completed',
      items: [
        SaleItem(
          productId: 'p1',
          name: 'Riz 5kg',
          qty: 1.5,
          unitPrice: 250.0,
          unitCost: 200.0,
        ),
        SaleItem(
          productId: 'p2',
          name: 'Huile 1L',
          qty: 1,
          unitPrice: 1500,
          unitCost: 1200.0,
        ),
      ],
    );
    const Product product = Product(
      id: 'p3',
      name: 'Sucre 1kg',
      category: 'Épicerie',
      unit: 'kg',
      purchasePrice: 600,
      salePrice: 750,
      quantity: 40,
      alertThreshold: 5,
    );

    final String csv = const SalesCsvBuilder()
        .build(sales: [sale], products: [product])
        .replaceFirst('\uFEFF', '');
    final List<String> rows = csv.split('\n');

    expect(
      rows[0],
      'Date;Produit;Quantite;PU;Sous-total;Total vente;Source;Statut',
    );
    expect(rows[1], '12/05/2026 14:30;Riz 5kg;1,50;250;375;375;kiosk;Payee');
    expect(rows[2], '12/05/2026 14:30;Huile 1L;1;1500;1500;375;kiosk;Payee');

    final int productsTitleIndex = rows.indexOf('PRODUITS');
    expect(productsTitleIndex, greaterThan(0));
    expect(
      rows[productsTitleIndex + 1],
      'Nom;Categorie;Quantite;Prix achat;Prix vente;Marge',
    );
    expect(rows[productsTitleIndex + 2], 'Sucre 1kg;Épicerie;40;600;750;150');
  });

  test('maps known statuses to French labels', () {
    final Sale cancelled = Sale(
      id: 's2',
      dateTime: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      total: 10,
      source: 'voice',
      status: 'cancelled',
      items: [SaleItem(productId: 'p1', name: 'Lait', qty: 1, unitPrice: 10)],
    );
    final Sale refunded = Sale(
      id: 's3',
      dateTime: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      total: 10,
      source: 'voice',
      status: 'refunded',
      items: [SaleItem(productId: 'p1', name: 'Lait', qty: 1, unitPrice: 10)],
    );

    final String csv = const SalesCsvBuilder().build(
      sales: [cancelled, refunded],
      products: [],
    );

    expect(csv, contains('Annulee'));
    expect(csv, contains('Remboursee'));
  });
}
