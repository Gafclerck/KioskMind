import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/cached_product_catalog_reader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_snapshot_store.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_catalog_snapshot_store.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/product_catalog_reader.dart';

ProductSnapshot _product(String id, {double price = 100, double stock = 5}) {
  return ProductSnapshot(
    id: id,
    name: 'Produit $id',
    aliases: const <String>[],
    unit: 'PIECE',
    price: price,
    purchasePrice: null,
    stock: stock,
    alertThreshold: 1,
    averageDailyQty: 0,
  );
}

/// Inner reader that can be cut off to simulate an offline repository.
class _FlakyReader implements ProductCatalogReader {
  _FlakyReader(this.products);

  final List<ProductSnapshot> products;
  bool online = true;

  @override
  Future<List<ProductSnapshot>> readActiveProducts() async {
    if (!online) throw StateError('offline');
    return products;
  }

  @override
  Future<List<ProductSnapshot>> readAllProducts() async {
    if (!online) throw StateError('offline');
    return products;
  }

  @override
  Future<ProductSnapshot?> findById(String productId) async {
    if (!online) throw StateError('offline');
    for (final ProductSnapshot product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }
}

class _RecordingStore implements CatalogSnapshotStore {
  _RecordingStore([this.seeded]);

  List<ProductSnapshot>? seeded;
  final List<List<ProductSnapshot>> saved = <List<ProductSnapshot>>[];

  @override
  Future<List<ProductSnapshot>?> load() async => seeded;

  @override
  Future<void> save(List<ProductSnapshot> products) async {
    saved.add(products);
  }
}

void main() {
  final List<ProductSnapshot> products = <ProductSnapshot>[
    _product('p1', price: 100),
    _product('p2', price: 200),
  ];

  group('CachedProductCatalogReader', () {
    test('serves the inner result and saves it to the store', () async {
      final _FlakyReader inner = _FlakyReader(products);
      final _RecordingStore store = _RecordingStore();
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: store,
      );

      final List<ProductSnapshot> result =
          await reader.readActiveProducts();

      expect(result, equals(products));
      expect(store.saved, hasLength(1));
      expect(store.saved.single, equals(products));
    });

    test('serves the session snapshot when the inner read fails', () async {
      final _FlakyReader inner = _FlakyReader(products);
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: _RecordingStore(),
      );
      await reader.readActiveProducts();

      inner.online = false;
      final List<ProductSnapshot> result =
          await reader.readActiveProducts();

      expect(result, equals(products));
    });

    test('serves the stored snapshot on a cold offline start', () async {
      final _FlakyReader inner = _FlakyReader(products)..online = false;
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: _RecordingStore(products),
      );

      final List<ProductSnapshot> result =
          await reader.readActiveProducts();

      expect(result, equals(products));
    });

    test('rethrows when offline and nothing is cached', () async {
      final _FlakyReader inner = _FlakyReader(products)..online = false;
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: _RecordingStore(),
      );

      await expectLater(
        reader.readActiveProducts(),
        throwsStateError,
      );
    });

    test('findById falls back to the snapshot when the inner read fails',
        () async {
      final _FlakyReader inner = _FlakyReader(products)..online = false;
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: _RecordingStore(products),
      );

      expect((await reader.findById('p1'))?.price, equals(100));
      expect(await reader.findById('missing'), isNull);
    });

    test('findById prefers the fresh inner result over the snapshot', () async {
      final _FlakyReader inner = _FlakyReader(products);
      final CachedProductCatalogReader reader = CachedProductCatalogReader(
        inner: inner,
        store: _RecordingStore(<ProductSnapshot>[
          _product('p1', price: 999), // stale snapshot
        ]),
      );

      final ProductSnapshot? found = await reader.findById('p1');

      expect(found?.price, equals(100));
    });
  });

  group('InMemoryCatalogSnapshotStore', () {
    test('returns null before anything is saved', () async {
      final InMemoryCatalogSnapshotStore store =
          InMemoryCatalogSnapshotStore();

      expect(await store.load(), isNull);
    });

    test('round-trips the snapshot it was given', () async {
      final InMemoryCatalogSnapshotStore store =
          InMemoryCatalogSnapshotStore();
      await store.save(products);

      final List<ProductSnapshot>? loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded, equals(products));
    });
  });
}