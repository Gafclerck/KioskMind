import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/add_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/edit_product_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/product_detail_page.dart';
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

const _lowStock = Product(
  id: '3',
  name: 'Sucre Roux',
  category: 'Alimentaire',
  unit: 'Paquets',
  purchasePrice: 1000,
  salePrice: 1200,
  quantity: 2,
  alertThreshold: 3,
);

const _atThreshold = Product(
  id: '4',
  name: 'Savon de Marseille',
  category: 'Hygiène',
  unit: 'Pièces',
  purchasePrice: 400,
  salePrice: 450,
  quantity: 3,
  alertThreshold: 3,
);

const _outOfStock = Product(
  id: '5',
  name: 'Huile de Palme',
  category: 'Alimentaire',
  unit: 'Bouteilles',
  purchasePrice: 2000,
  salePrice: 2500,
  quantity: 0,
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

  @override
  Future<List<Product>> getProducts() async => const [_riz];

  @override
  Future<Product?> getProductById(String productId) async =>
      productId == _riz.id ? _riz : null;
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

  testWidgets('opens the detail page when tapping a product card', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailPage), findsOneWidget);
    expect(find.text('Fiche Produit'), findsOneWidget);
    expect(find.text('Marge Net'), findsOneWidget);
    expect(find.text('+800 FCFA'), findsOneWidget);
  });

  testWidgets('opens the edit page from the detail page', (tester) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modifier Fiche'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProductPage), findsOneWidget);
  });

  testWidgets('shows the stock quantity field again when editing', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('test_Riz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier Fiche'));
    await tester.pumpAndSettle();

    expect(find.text('Quantité en rayon'), findsOneWidget);
  });

  testWidgets('updates the product through the edit page', (tester) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Modifier la fiche'));
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

  testWidgets('saves a new quantity when editing', (tester) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Modifier la fiche'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(repository.updated.single.quantity, 11);
  });

  testWidgets('deletes a product after confirmation', (tester) async {
    final repository = _RecordingProductRepository();
    await tester.pumpWidget(_pageWithRepository(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Supprimer'));
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

    await tester.tap(find.byTooltip('Supprimer'));
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

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Erreur de suppression'), findsOneWidget);
  });

  testWidgets('shows the quantity and detail actions on a card', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.text('Modifier Qte'), findsOneWidget);
    expect(find.text('Détails'), findsOneWidget);
    expect(find.text('Seuil d\'alerte : 3 sacs'), findsOneWidget);
    expect(find.text('10 sacs'), findsOneWidget);
    expect(find.text('5,000 F / Sacs'), findsOneWidget);
  });

  testWidgets('filters the list by category', (tester) async {
    await tester.pumpWidget(
      _page(const [
        _riz,
        Product(
          id: '2',
          name: 'Eau de Savon',
          category: 'Hygiène',
          unit: 'Bouteilles',
          purchasePrice: 300,
          salePrice: 500,
          quantity: 4,
          alertThreshold: 2,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsOneWidget);
    expect(find.text('Eau de Savon'), findsOneWidget);

    // La rangée de filtres déborde sur mobile étroit : rendre le chip visible
    // avant de le taper, sinon le tap tombe dans le vide.
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Hygiène'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Hygiène'));
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsNothing);
    expect(find.text('Eau de Savon'), findsOneWidget);
  });

  testWidgets('filters the list by search query', (tester) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'riz');
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'inexistant');
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsNothing);
    expect(find.text('Aucun résultat'), findsOneWidget);
  });

  testWidgets('clears the search query', (tester) async {
    await tester.pumpWidget(_page(const [_riz]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsOneWidget);
  });

  testWidgets('marks a product below its threshold as critical', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_lowStock]));
    await tester.pumpAndSettle();

    expect(find.text('Niveau critique'), findsOneWidget);
  });

  testWidgets('marks an out of stock product', (tester) async {
    await tester.pumpWidget(_page(const [_outOfStock]));
    await tester.pumpAndSettle();

    // Le chip de filtre porte le même libellé : on cible le badge de la carte.
    expect(
      find.descendant(
        of: find.byType(StockAlertBadge),
        matching: find.text('Rupture de Stock'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('filters the list on out of stock products', (tester) async {
    await tester.pumpWidget(_page(const [_riz, _outOfStock]));
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsOneWidget);
    expect(find.text('Huile de Palme'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilterChip, 'Rupture de Stock'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('test_Riz'), findsNothing);
    expect(find.text('Huile de Palme'), findsOneWidget);
  });

  testWidgets('marks a product at its threshold as a rupture warning', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const [_atThreshold]));
    await tester.pumpAndSettle();

    expect(find.text('Alerte Rupture'), findsOneWidget);
  });
}
