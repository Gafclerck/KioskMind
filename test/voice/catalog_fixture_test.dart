import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';

void main() {
  group('parseCatalogFixture', () {
    const String valid = '''
{
  "version": 1,
  "currency": "XOF",
  "products": [
    {
      "id": "p_sucre",
      "name": "Sucre",
      "aliases": ["sucre", "sucres"],
      "unit": "SACHET",
      "price": 100,
      "purchasePrice": 75,
      "stock": 40,
      "alertThreshold": 10,
      "averageDailyQty": 6
    }
  ]
}
''';

    test('reads a well-formed catalog', () {
      final List<ProductSnapshot> products = parseCatalogFixture(valid);

      expect(products, hasLength(1));
      final ProductSnapshot sucre = products.single;
      expect(sucre.id, 'p_sucre');
      expect(sucre.name, 'Sucre');
      expect(sucre.aliases, <String>['sucre', 'sucres']);
      expect(sucre.unit, 'SACHET');
      expect(sucre.price, 100);
      expect(sucre.purchasePrice, 75);
      expect(sucre.stock, 40);
      expect(sucre.alertThreshold, 10);
      expect(sucre.averageDailyQty, 6);
      expect(sucre.isArchived, isFalse);
    });

    test('rejects an unexpected version', () {
      expect(
        () => parseCatalogFixture(
          valid.replaceAll('"version": 1', '"version": 2'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a duplicate product identifier', () {
      final String entry = '''
    {
      "id": "p_sucre",
      "name": "Sucre",
      "aliases": ["sucre"],
      "unit": "SACHET",
      "price": 100,
      "stock": 40,
      "alertThreshold": 10,
      "averageDailyQty": 6
    }''';
      final String doubled = valid.replaceFirst(
        '  "products": [',
        '  "products": [$entry,',
      );
      expect(
        () => parseCatalogFixture(doubled),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('duplique'),
          ),
        ),
      );
    });

    test('rejects an identifier Firestore could not use as a document id', () {
      final String slashed = valid.replaceAll(
        '"p_sucre"',
        '"produits/p_sucre"',
      );
      expect(
        () => parseCatalogFixture(slashed),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a negative price', () {
      final String negative = valid.replaceAll('"price": 100', '"price": -1');
      expect(
        () => parseCatalogFixture(negative),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing field', () {
      final String incomplete = valid.replaceAll('"unit": "SACHET",\n', '');
      expect(
        () => parseCatalogFixture(incomplete),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty product list', () {
      expect(
        () => parseCatalogFixture(
          '{"version": 1, "currency": "XOF", "products": []}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('loudly rejects malformed JSON', () {
      expect(() => parseCatalogFixture('{'), throwsA(isA<FormatException>()));
    });
  });

  group('the bundled fixture', () {
    late List<ProductSnapshot> products;

    setUpAll(() {
      final File file = File(catalogFixtureAsset);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '$catalogFixtureAsset doit exister et etre declare dans pubspec.yaml',
      );
      products = parseCatalogFixture(file.readAsStringSync());
    });

    test('is not empty', () {
      expect(products, isNotEmpty);
    });

    test('has unique, Firestore-safe identifiers', () {
      final Set<String> ids = products
          .map((ProductSnapshot product) => product.id)
          .toSet();
      expect(ids, hasLength(products.length));
      for (final ProductSnapshot product in products) {
        expect(product.id, isNot(contains('/')));
      }
    });

    test('gives every product a name, a unit and a usable price', () {
      for (final ProductSnapshot product in products) {
        expect(product.name, isNotEmpty, reason: product.id);
        expect(product.unit, isNotEmpty, reason: product.id);
        expect(product.price, greaterThanOrEqualTo(0), reason: product.id);
      }
    });

    test('covers every unit the demo scenario needs', () {
      final Set<String> units = products
          .map((ProductSnapshot product) => product.unit)
          .toSet();
      expect(units, containsAll(<String>['PIECE', 'KG', 'SACHET']));
    });

    test('contains an archived product so exclusion can be tested', () {
      expect(
        products.any((ProductSnapshot product) => product.isArchived),
        isTrue,
      );
    });

    test('has an ambiguous name for the resolver to ask about', () {
      // The demo scenario hinges on "vendu de l'huile" being genuinely
      // ambiguous between two oils, so it must stay a real ambiguity in the
      // catalog rather than one manufactured by the parser.
      final int huileMatches = products.where((ProductSnapshot product) {
        return product.name.toLowerCase().contains('huile') ||
            product.aliases.contains('huile');
      }).length;
      expect(huileMatches, greaterThan(1));
    });

    test('gives every product at least one alias a merchant could say', () {
      for (final ProductSnapshot product in products) {
        expect(product.aliases, isNotEmpty, reason: product.id);
      }
    });
  });

  group('InMemoryProductCatalog', () {
    ProductSnapshot product(
      String id, {
      required double stock,
      bool isArchived = false,
    }) {
      return ProductSnapshot(
        id: id,
        name: id,
        aliases: const <String>[],
        unit: 'PIECE',
        price: 100,
        purchasePrice: null,
        stock: stock,
        alertThreshold: 0,
        averageDailyQty: 0,
        isArchived: isArchived,
      );
    }

    test('lists only active products, sorted by name', () async {
      final InMemoryProductCatalog catalog =
          InMemoryProductCatalog(<ProductSnapshot>[
            product('sucre', stock: 1),
            product('lait', stock: 2),
            product('vieux', stock: 3, isArchived: true),
          ]);

      final List<ProductSnapshot> active = await catalog.readActiveProducts();
      expect(active.map((ProductSnapshot p) => p.id).toList(), <String>[
        'lait',
        'sucre',
      ]);
    });

    test(
      'returns an archived product on findById so callers can tell it apart',
      () async {
        final InMemoryProductCatalog catalog = InMemoryProductCatalog(
          <ProductSnapshot>[product('vieux', stock: 3, isArchived: true)],
        );

        expect(await catalog.findById('vieux'), isNotNull);
        expect((await catalog.findById('vieux'))!.isArchived, isTrue);
        expect(await catalog.findById('absent'), isNull);
      },
    );

    test('computes a projected stock without writing', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      expect(catalog.stockAfter('sucre', -3), 7);
      expect(catalog.stockAfter('sucre', 5), 15);
      expect(catalog.stockOf('sucre'), 10);
      expect(catalog.stockAfter('absent', 1), isNull);
    });

    test('ignores a second sale for an already known command', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );
      final CommandContext context = (
        commandId: 'cmd-1',
        dateTime: DateTime(2026, 3, 1),
        source: CommandSource.voice,
      );
      const RecordSaleResult result = (
        saleId: 'cmd-1',
        total: 300,
        lines: <SaleLineResult>[],
      );

      catalog.applySale(context, result);
      catalog.applySale(context, result);

      expect(catalog.stockOf('sucre'), 10);
      expect(catalog.saleById('cmd-1'), isNotNull);
    });
  });
}
