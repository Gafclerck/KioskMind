import '../../domain/entities/product_snapshot.dart';

/// Local persistence of the last-known catalog snapshot.
///
/// The production store (SharedPreferences) lets the voice module route basic
/// commands on a cold start with no connection at all, instead of depending on
/// Firestore's own best-effort cache. The in-memory store is the test default:
/// it keeps a session's catalog available while a repository call fails, without
/// touching a platform channel.
abstract interface class CatalogSnapshotStore {
  /// The stored snapshot, or null when nothing has been saved yet (or the
  /// stored value cannot be read back).
  Future<List<ProductSnapshot>?> load();

  /// Remembers [products] so a later offline read can serve them.
  Future<void> save(List<ProductSnapshot> products);
}