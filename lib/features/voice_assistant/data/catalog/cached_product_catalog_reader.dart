import '../../domain/entities/product_snapshot.dart';
import '../../domain/ports/product_catalog_reader.dart';
import 'catalog_snapshot_store.dart';

/// Catalog reader that keeps the last-known product list so the voice module can
/// keep routing while the repository (Firestore) is unreachable.
///
/// Freshness comes first: while the inner reader answers, its result is served
/// and remembered. Only when the inner reader fails (an offline `get()` with a
/// cold Firestore cache, a dropped connection) does this reader fall back to the
/// snapshot in memory, then on disk. Nothing is stored from a failed read, so an
/// offline session never hides a network problem behind stale data when fresh
/// data would have been cheap.
final class CachedProductCatalogReader implements ProductCatalogReader {
  CachedProductCatalogReader({
    required this.inner,
    required this.store,
  });

  final ProductCatalogReader inner;
  final CatalogSnapshotStore store;

  /// Snapshot served by the last successful read of this session.
  List<ProductSnapshot>? _memory;

  @override
  Future<List<ProductSnapshot>> readActiveProducts() {
    return _read(() => inner.readActiveProducts());
  }

  @override
  Future<List<ProductSnapshot>> readAllProducts() {
    return _read(() => inner.readAllProducts());
  }

  @override
  Future<ProductSnapshot?> findById(String productId) async {
    try {
      return await inner.findById(productId);
    } catch (_) {
      final List<ProductSnapshot>? cached = _memory ?? await store.load();
      if (cached == null) return null;
      _memory = cached;
      for (final ProductSnapshot product in cached) {
        if (product.id == productId) return product;
      }
      return null;
    }
  }

  Future<List<ProductSnapshot>> _read(
    Future<List<ProductSnapshot>> Function() load,
  ) async {
    try {
      final List<ProductSnapshot> products = await load();
      _memory = products;
      await store.save(products);
      return products;
    } catch (_) {
      final List<ProductSnapshot>? cached = _memory ?? await store.load();
      if (cached != null) {
        _memory = cached;
        return cached;
      }
      rethrow;
    }
  }
}