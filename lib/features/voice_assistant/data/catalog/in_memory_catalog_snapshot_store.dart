import '../../domain/entities/product_snapshot.dart';
import 'catalog_snapshot_store.dart';

/// In-session [CatalogSnapshotStore] keeping the last-known catalog in memory.
///
/// Default wiring for the voice composition root: no platform channel, so tests
/// never need a SharedPreferences mock. `main()` overrides the provider with the
/// SharedPreferences-backed store to also survive an app restart offline.
final class InMemoryCatalogSnapshotStore implements CatalogSnapshotStore {
  List<ProductSnapshot>? _snapshot;

  @override
  Future<List<ProductSnapshot>?> load() async => _snapshot;

  @override
  Future<void> save(List<ProductSnapshot> products) async {
    _snapshot = List<ProductSnapshot>.unmodifiable(products);
  }
}