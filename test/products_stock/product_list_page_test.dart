import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/add_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/product_list_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';

Widget _page(List<Product> products) => ProviderScope(
  overrides: [productsProvider.overrideWith((ref) => Stream.value(products))],
  child: const MaterialApp(home: ProductListPage()),
);

void main() {
  testWidgets('shows the empty state when there is no product', (tester) async {
    await tester.pumpWidget(_page(const []));
    await tester.pumpAndSettle();

    expect(find.text('Aucun produit'), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget);
  });

  testWidgets('shows the products when the list is not empty', (tester) async {
    await tester.pumpWidget(
      _page(const [
        Product(
          id: '1',
          name: 'test_Riz',
          category: 'Alimentaire',
          unit: 'Sacs',
          purchasePrice: 4200,
          salePrice: 5000,
          quantity: 10,
          alertThreshold: 3,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsOneWidget);
    expect(find.text('Aucun produit'), findsNothing);
  });

  testWidgets('opens the add product page from the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter un produit'));
    await tester.pumpAndSettle();

    expect(find.byType(AddProductPage), findsOneWidget);
    expect(find.text('Nouveau Produit'), findsOneWidget);
  });
}
