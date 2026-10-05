import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/real_product_catalog_reader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_stock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';

final class _FakeProductRepository implements ProductRepository {
  final Map<String, Product> products = <String, Product>{};

  @override
  Future<void> createProduct(Product product) async {
    products[product.id] = product;
  }

  @override
  Future<void> updateProduct(Product product) async {
    products[product.id] = product;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    products.remove(productId);
  }

  @override
  Stream<List<Product>> watchProducts() =>
      Stream<List<Product>>.value(products.values.toList());

  @override
  Future<List<Product>> getProducts() async => products.values.toList();

  @override
  Future<Product?> getProductById(String productId) async =>
      products[productId];
}

Product _makeProduct({
  required String id,
  required String name,
  required int salePrice,
  required int purchasePrice,
  required int quantity,
  required int alertThreshold,
  String unit = 'PIECE',
  String category = 'Alimentation',
}) {
  return Product(
    id: id,
    name: name,
    category: category,
    unit: unit,
    purchasePrice: purchasePrice,
    salePrice: salePrice,
    quantity: quantity,
    alertThreshold: alertThreshold,
  );
}

void main() {
  group('RealProductCatalogReader', () {
    late _FakeProductRepository repository;
    late RealProductCatalogReader reader;

    setUp(() {
      repository = _FakeProductRepository();
      reader = RealProductCatalogReader(repository);
    });

    test('maps products to ProductSnapshot with correct fields', () async {
      final product = _makeProduct(
        id: 'p_riz',
        name: 'Riz parfume 5kg',
        salePrice: 4500,
        purchasePrice: 4000,
        quantity: 15,
        alertThreshold: 3,
        unit: 'SAC',
      );
      await repository.createProduct(product);

      final active = await reader.readActiveProducts();
      expect(active.length, equals(1));

      final snapshot = active.first;
      expect(snapshot.id, equals('p_riz'));
      expect(snapshot.name, equals('Riz parfume 5kg'));
      expect(snapshot.price, equals(4500.0));
      expect(snapshot.purchasePrice, equals(4000.0));
      expect(snapshot.stock, equals(15.0));
      expect(snapshot.alertThreshold, equals(3.0));
      expect(snapshot.unit, equals('SAC'));
      expect(snapshot.aliases, containsAll(<String>['riz parfume', 'riz']));
      expect(snapshot.isArchived, isFalse);
      expect(snapshot.averageDailyQty, equals(0.0));
    });

    test('readAllProducts returns all mapped products', () async {
      await repository.createProduct(
        _makeProduct(
          id: 'p1',
          name: 'Produit 1',
          salePrice: 100,
          purchasePrice: 80,
          quantity: 10,
          alertThreshold: 2,
        ),
      );
      await repository.createProduct(
        _makeProduct(
          id: 'p2',
          name: 'Produit 2',
          salePrice: 200,
          purchasePrice: 150,
          quantity: 5,
          alertThreshold: 1,
        ),
      );

      final all = await reader.readAllProducts();
      expect(all.length, equals(2));
      expect(all.map((p) => p.id), containsAll(<String>['p1', 'p2']));
    });

    test(
      'findById returns mapped product when present, null when absent',
      () async {
        await repository.createProduct(
          _makeProduct(
            id: 'p_eau',
            name: 'Eau minerale',
            salePrice: 500,
            purchasePrice: 300,
            quantity: 24,
            alertThreshold: 5,
          ),
        );

        final found = await reader.findById('p_eau');
        expect(found, isNotNull);
        expect(found!.name, equals('Eau minerale'));
        expect(found.stock, equals(24.0));

        final missing = await reader.findById('unknown_id');
        expect(missing, isNull);
      },
    );
  });

  group('RealQueryStockHandler', () {
    late _FakeProductRepository repository;
    late RealProductCatalogReader catalogReader;
    late RealQueryStockHandler handler;

    final CommandContext context = (
      commandId: 'cmd-stock-1',
      dateTime: DateTime(2026, 3, 1, 10),
      source: CommandSource.voice,
    );

    setUp(() {
      repository = _FakeProductRepository();
      catalogReader = RealProductCatalogReader(repository);
      handler = RealQueryStockHandler(catalogReader);
    });

    test('has intentId query_stock', () {
      expect(handler.intentId, equals('query_stock'));
    });

    test('returns stock info successfully for existing product', () async {
      await repository.createProduct(
        _makeProduct(
          id: 'p_sucre',
          name: 'Sucre roux',
          salePrice: 750,
          purchasePrice: 600,
          quantity: 12,
          alertThreshold: 2,
          unit: 'KG',
        ),
      );

      final result = await handler.execute(
        context,
        const QueryStockInput(productId: 'p_sucre'),
      );

      expect(result, isA<Success<QueryStockResult>>());
      final success = result as Success<QueryStockResult>;
      expect(success.value.productId, equals('p_sucre'));
      expect(success.value.productName, equals('Sucre roux'));
      expect(success.value.stock, equals(12.0));
      expect(success.value.unit, equals('KG'));
      expect(success.value.alertThreshold, equals(2.0));
    });

    test(
      'returns UnknownProduct failure when product does not exist',
      () async {
        final result = await handler.execute(
          context,
          const QueryStockInput(productId: 'non_existent'),
        );

        expect(result, isA<Failed<QueryStockResult>>());
        final failure = (result as Failed<QueryStockResult>).failure;
        expect(failure, isA<UnknownProduct>());
        expect((failure as UnknownProduct).productId, equals('non_existent'));
      },
    );

    test(
      'returns ArchivedProduct failure when product is archived in catalog',
      () async {
        final inMemoryCatalog = InMemoryProductCatalog(<ProductSnapshot>[
          const ProductSnapshot(
            id: 'p_archived',
            name: 'Savon ancien',
            aliases: <String>[],
            unit: 'PIECE',
            price: 150,
            purchasePrice: null,
            stock: 3,
            alertThreshold: 1,
            averageDailyQty: 0,
            isArchived: true,
          ),
        ]);
        final archivedHandler = RealQueryStockHandler(inMemoryCatalog);

        final result = await archivedHandler.execute(
          context,
          const QueryStockInput(productId: 'p_archived'),
        );

        expect(result, isA<Failed<QueryStockResult>>());
        final failure = (result as Failed<QueryStockResult>).failure;
        expect(failure, isA<ArchivedProduct>());
        expect((failure as ArchivedProduct).productId, equals('p_archived'));
        expect((failure).productName, equals('Savon ancien'));
      },
    );
  });
}
