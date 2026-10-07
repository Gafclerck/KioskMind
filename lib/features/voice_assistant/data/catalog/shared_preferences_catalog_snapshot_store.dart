import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/product_snapshot.dart';
import 'catalog_snapshot_store.dart';

/// Disk-backed [CatalogSnapshotStore] built on SharedPreferences.
///
/// A corrupted or half-written value is treated as absent (returns null) so a
/// storage bug can never take the voice module down.
final class SharedPreferencesCatalogSnapshotStore
    implements CatalogSnapshotStore {
  const SharedPreferencesCatalogSnapshotStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'voice_catalog_snapshot_v1';

  @override
  Future<List<ProductSnapshot>?> load() async {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return <ProductSnapshot>[
        for (final dynamic entry in decoded)
          if (entry is Map)
            ProductSnapshot.fromJson(Map<String, dynamic>.from(entry)),
      ];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(List<ProductSnapshot> products) async {
    await _prefs.setString(
      _key,
      jsonEncode(<Map<String, dynamic>>[
        for (final ProductSnapshot product in products) product.toJson(),
      ]),
    );
  }
}