import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/real_product_catalog_reader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';

final class _MemoryProductRepo implements ProductRepository {
  final List<Product> _products = <Product>[];

  @override
  Future<void> createProduct(Product product) async => _products.add(product);

  @override
  Future<void> updateProduct(Product product) async {}

  @override
  Future<void> deleteProduct(String productId) async {}

  @override
  Stream<List<Product>> watchProducts() => Stream<List<Product>>.value(_products);

  @override
  Future<List<Product>> getProducts() async => _products;

  @override
  Future<Product?> getProductById(String productId) async {
    for (final Product p in _products) {
      if (p.id == productId) return p;
    }
    return null;
  }
}

void main() {
  group('Real Stock Voice Resolution with Auto-Generated Aliases', () {
    late _MemoryProductRepo repo;
    late RealProductCatalogReader reader;
    const TextNormalizer normalizer = TextNormalizer();
    const VoiceConfig config = VoiceConfig();

    setUp(() async {
      repo = _MemoryProductRepo();
      reader = RealProductCatalogReader(repo);

      // Create realistic merchant products in stock
      await repo.createProduct(
        const Product(
          id: 'p_riz_50kg',
          name: 'Sac de riz 50kg',
          category: 'Céréales',
          unit: 'SAC',
          purchasePrice: 20000,
          salePrice: 24000,
          quantity: 20,
          alertThreshold: 5,
        ),
      );

      await repo.createProduct(
        const Product(
          id: 'p_huile_dinor',
          name: 'Huile Dinor 1.5L',
          category: 'Huiles',
          unit: 'BOUTEILLE',
          purchasePrice: 1200,
          salePrice: 1500,
          quantity: 50,
          alertThreshold: 10,
        ),
      );
    });

    test('real products automatically generate aliases for spoken resolution', () async {
      final List<ProductSnapshot> snapshots = await reader.readActiveProducts();
      final ProductResolver resolver = ProductResolver(
        products: snapshots,
        config: config,
        normalizer: normalizer,
      );

      // 1. "riz" matches "Sac de riz 50kg"
      final ProductSpan? spanRiz = resolver.matchAt(<String>['riz'], 0);
      expect(spanRiz, isNotNull);
      expect(spanRiz!.resolution.product?.id, equals('p_riz_50kg'));

      // 2. "sac de riz" matches "Sac de riz 50kg"
      final ProductSpan? spanSacRiz = resolver.matchAt(<String>['sac', 'de', 'riz'], 0);
      expect(spanSacRiz, isNotNull);
      expect(spanSacRiz!.resolution.product?.id, equals('p_riz_50kg'));

      // 3. "dinor" matches "Huile Dinor 1.5L"
      final ProductSpan? spanDinor = resolver.matchAt(<String>['dinor'], 0);
      expect(spanDinor, isNotNull);
      expect(spanDinor!.resolution.product?.id, equals('p_huile_dinor'));

      // 4. "huile dinor" matches "Huile Dinor 1.5L"
      final ProductSpan? spanHuileDinor = resolver.matchAt(<String>['huile', 'dinor'], 0);
      expect(spanHuileDinor, isNotNull);
      expect(spanHuileDinor!.resolution.product?.id, equals('p_huile_dinor'));
    });

    test('item extractor identifies product even when quantity is missing or misheard', () async {
      final List<ProductSnapshot> snapshots = await reader.readActiveProducts();
      final ProductResolver resolver = ProductResolver(
        products: snapshots,
        config: config,
        normalizer: normalizer,
      );

      final ItemListExtractor items = ItemListExtractor(
        resolver: resolver,
        lines: LineExtractor(
          numbers: const FrenchNumberParser(),
          config: config,
        ),
      );

      // Utterance: "vendu du riz" -> product recognized, quantity missing
      final ItemListReading readingMissingQty = items.read(
        <String>['vendu', 'du', 'riz'],
        from: 1,
        requiresQuantity: true,
      );

      // The product IS recognized (not unknown product!)
      expect(readingMissingQty.products.length, equals(1));
      expect(readingMissingQty.products.first.id, equals('p_riz_50kg'));

      // The doubt is missingQuantity ("Combien ?"), NOT unknownProduct ("Quel produit ?")
      expect(readingMissingQty.doubts.length, equals(1));
      expect(readingMissingQty.doubts.first.kind, equals(DoubtKind.missingQuantity));
      expect(
        ClarificationSlot.forDoubt(
          readingMissingQty.doubts.first.kind,
          hasItems: false,
        ),
        equals(ClarificationSlot.itemQty),
      );
    });

    test('item extractor identifies product and quantity when full line is spoken', () async {
      final List<ProductSnapshot> snapshots = await reader.readActiveProducts();
      final ProductResolver resolver = ProductResolver(
        products: snapshots,
        config: config,
        normalizer: normalizer,
      );

      final ItemListExtractor items = ItemListExtractor(
        resolver: resolver,
        lines: LineExtractor(
          numbers: const FrenchNumberParser(),
          config: config,
        ),
      );

      // Utterance: "vendu deux sacs de riz"
      final ItemListReading readingComplete = items.read(
        <String>['vendu', 'deux', 'sacs', 'de', 'riz'],
        from: 1,
        requiresQuantity: true,
      );

      expect(readingComplete.doubts, isEmpty);
      expect(readingComplete.items.length, equals(1));
      expect(readingComplete.items.first.product.id, equals('p_riz_50kg'));
      expect(readingComplete.items.first.qty, equals(2.0));
    });
  });
}
