import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/add_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/edit_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/product_list_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/product_card.dart';

const _riz = Product(
  id: '1',
  name: 'test_Riz',
  category: 'Alimentaire',
  unit: 'Sacs',
  purchasePrice: 4200,
  salePrice: 5000,
  quantity: 10,
  alertThreshold: 3,
);

class _RecordingProductRepository implements ProductRepository {
  final List<Product> created = [];
  final List<Product> updated = [];
  final List<String> deleted = [];
  Object? throwOnAction;

  @override
  Future<void> createProduct(Product product) async => created.add(product);

  @override
  Future<void> updateProduct(Product product) async {
    if (throwOnAction != null) throw throwOnAction!;
    updated.add(product);
  }

  @override
  Future<void> deleteProduct(String productId) async {
    if (throwOnAction != null) throw throwOnAction!;
    deleted.add(productId);
  }

  @override
  Stream<List<Product>> watchProducts() => Stream.value(const [_riz]);
}

Widget _page(List<Product> products) => ProviderScope(
  overrides: [productsProvider.overrideWith((ref) => Stream.value(products))],
  child: const MaterialApp(home: ProductListPage()),
);

Widget _pageWithRepository(ProductRepository repository) => ProviderScope(
  overrides: [
    productsProvider.overrideWith((ref) => repository.watchProducts()),
    productRepositoryProvider.overrideWithValue(repository),
  ],
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
    await tester.pumpWidget(_page(const [_riz]));
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

  testWidgets('opens the edit page when tapping a product card', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProductPage), findsOneWidget);
    expect(find.text('Modifier le Produit'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);
  });

  testWidgets('keeps the quantity field hidden when editing', (tester) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();

    expect(find.text('Quantité initiale'), findsNothing);
  });

  testWidgets('updates the product through the edit page', (tester) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('product_form_name')),
      'Riz Royal',
    );
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(find.text('Produit mis à jour !'), findsOneWidget);
    expect(repository.updated, hasLength(1));
    expect(repository.updated.single.id, '1');
    expect(repository.updated.single.name, 'Riz Royal');
    expect(repository.updated.single.quantity, 10);
  });

  testWidgets('deletes a product after confirmation', (tester) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ce produit ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['1']);
  });

  testWidgets('does not delete when the confirmation is cancelled', (
    tester,
  ) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isEmpty);
  });

  testWidgets('surfaces an error when the deletion fails', (tester) async {
    final repository = _RecordingProductRepository()
      ..throwOnAction = StateError('offline');
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Erreur de suppression'), findsOneWidget);
  });

  testWidgets('offers the edit and delete actions on a card', (tester) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    expect(find.byType(ProductCard), findsOneWidget);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
  });
}
