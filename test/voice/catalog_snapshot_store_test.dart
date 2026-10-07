import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/shared_preferences_catalog_snapshot_store.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductSnapshot _product(String id) {
  return ProductSnapshot(
    id: id,
    name: 'Riz parfume 5kg',
    aliases: const <String>['riz parfume', 'riz'],
    unit: 'SAC',
    price: 4500,
    purchasePrice: 4000,
    stock: 15,
    alertThreshold: 3,
    averageDailyQty: 2.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesCatalogSnapshotStore', () {
    test('returns null when nothing has been stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCatalogSnapshotStore store =
          SharedPreferencesCatalogSnapshotStore(prefs);

      expect(await store.load(), isNull);
    });

    test('round-trips a snapshot preserving every field', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCatalogSnapshotStore store =
          SharedPreferencesCatalogSnapshotStore(prefs);

      final ProductSnapshot original = _product('p_riz');
      await store.save(<ProductSnapshot>[original]);
      final List<ProductSnapshot>? loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
      final ProductSnapshot restored = loaded!.single;
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.aliases, equals(original.aliases));
      expect(restored.unit, equals(original.unit));
      expect(restored.price, equals(original.price));
      expect(restored.purchasePrice, equals(original.purchasePrice));
      expect(restored.stock, equals(original.stock));
      expect(restored.alertThreshold, equals(original.alertThreshold));
      expect(restored.averageDailyQty, equals(original.averageDailyQty));
      expect(restored.isArchived, equals(original.isArchived));
    });

    test('returns null on a corrupted stored value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'voice_catalog_snapshot_v1': 'not json at all',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCatalogSnapshotStore store =
          SharedPreferencesCatalogSnapshotStore(prefs);

      expect(await store.load(), isNull);
    });

    test('overwrites the previous snapshot on the next save', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCatalogSnapshotStore store =
          SharedPreferencesCatalogSnapshotStore(prefs);

      await store.save(<ProductSnapshot>[_product('old')]);
      await store.save(<ProductSnapshot>[_product('new')]);
      final List<ProductSnapshot>? loaded = await store.load();

      expect(loaded?.single.id, equals('new'));
    });
  });
}