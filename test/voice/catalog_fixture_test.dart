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

    test('rejects a product list holding something else than objects', () {
      final String broken = valid.replaceFirst(
        '  "products": [',
        '  "products": ["sucre",',
      );
      expect(
        () => parseCatalogFixture(broken),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects aliases that are not a list of strings', () {
      final String broken = valid.replaceAll(
        '"aliases": ["sucre", "sucres"]',
        '"aliases": "sucre"',
      );
      expect(
        () => parseCatalogFixture(broken),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a blank alias', () {
      final String broken = valid.replaceAll(
        '"aliases": ["sucre", "sucres"]',
        '"aliases": ["sucre", "  "]',
      );
      expect(
        () => parseCatalogFixture(broken),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a blank name or unit', () {
      final String noName = valid.replaceAll('"name": "Sucre"', '"name": "  "');
      final String noUnit = valid.replaceAll('"unit": "SACHET"', '"unit": ""');

      expect(
        () => parseCatalogFixture(noName),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseCatalogFixture(noUnit),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a version that is not a whole number', () {
      for (final String version in <String>['"1.5"', '"un"', 'null']) {
        expect(
          () => parseCatalogFixture(
            valid.replaceAll('"version": 1', '"version": $version'),
          ),
          throwsA(isA<FormatException>()),
          reason: version,
        );
      }
    });

    test('rejects a missing version, currency or product list', () {
      for (final String key in <String>['version', 'currency', 'products']) {
        final String broken = valid.replaceFirst(
          RegExp('  "$key": [^\n]*\n'),
          '',
        );
        expect(
          () => parseCatalogFixture(broken),
          throwsA(isA<FormatException>()),
          reason: key,
        );
      }
    });

    test('rejects a non-numeric price, stock or habit', () {
      for (final String key in <String>['price', 'stock', 'averageDailyQty']) {
        expect(
          () => parseCatalogFixture(
            valid.replaceFirst(RegExp('"$key": [0-9.]+'), '"$key": "beaucoup"'),
          ),
          throwsA(isA<FormatException>()),
          reason: key,
        );
      }
    });

    test('rejects a non-numeric purchase price', () {
      final String broken = valid.replaceAll(
        '"purchasePrice": 75',
        '"purchasePrice": "gratuit"',
      );
      expect(
        () => parseCatalogFixture(broken),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-boolean archived flag', () {
      final String broken = valid.replaceAll(
        '"averageDailyQty": 6',
        '"averageDailyQty": 6, "isArchived": "oui"',
      );
      expect(
        () => parseCatalogFixture(broken),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts a whole version written as a double', () {
      final List<ProductSnapshot> products = parseCatalogFixture(
        valid.replaceAll('"version": 1', '"version": 1.0'),
      );

      expect(products, hasLength(1));
    });

    test('reads an archived flag and an absent optional number', () {
      final List<ProductSnapshot> products = parseCatalogFixture(
        valid
            .replaceFirst(
              '"averageDailyQty": 6',
              '"averageDailyQty": 6, "isArchived": true',
            )
            .replaceFirst('  "purchasePrice": 75,\n', ''),
      );

      expect(products.single.isArchived, isTrue);
      expect(products.single.purchasePrice, isNull);
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

    test('reads the stock back after a write', () async {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      expect(catalog.stockOf('sucre'), 10);
      catalog.applySale(_context('cmd-1'), _sucreSale);

      expect(catalog.stockOf('sucre'), 7);
      expect(catalog.stockOf('absent'), isNull);
    });

    test('applies a restock as a purchase movement with a delta', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      catalog.applyRestock(_context('cmd-1'), const (
        movementIds: <String>['cmd-1-0'],
        lines: <RestockLineResult>[
          (
            productId: 'sucre',
            name: 'sucre',
            qty: 5,
            appliedUnitCost: 70,
            resultingStock: 15,
          ),
        ],
      ));

      expect(catalog.stockOf('sucre'), 15);
      expect(catalog.movements.single.id, 'cmd-1-0');
      expect(catalog.movements.single.type, 'PURCHASE');
      expect(catalog.movements.single.delta, 5);
      expect(catalog.movements.single.unitCost, 70);
      expect(catalog.movements.single.dateTime, DateTime(2026, 3, 1));
    });

    test('ignores a second sale for an already known command', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      catalog.applySale(_context('cmd-1'), _sucreSale);
      catalog.applySale(_context('cmd-1'), _sucreSale);

      expect(catalog.stockOf('sucre'), 7);
      expect(catalog.saleById('cmd-1'), isNotNull);
    });

    test('knows nothing about a command that never succeeded', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      expect(catalog.saleResultByCommandId('cmd-1'), isNull);
      expect(catalog.saleById('cmd-1'), isNull);
      expect(catalog.movements, isEmpty);
    });

    test('stops offering a cancelled sale for an idempotent replay', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );
      catalog.applySale(_context('cmd-1'), _sucreSale);
      expect(catalog.saleResultByCommandId('cmd-1'), isNotNull);

      catalog.applyCancellation('cmd-1', DateTime(2026, 3, 1, 11), const [
        _sucreRestored,
      ]);

      expect(
        catalog.saleResultByCommandId('cmd-1'),
        isNull,
        reason: 'une vente annulee ne doit pas etre rejouee',
      );
      expect(catalog.stockOf('sucre'), 10);
    });

    test('ignores a cancellation of a sale already cancelled', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );
      catalog.applySale(_context('cmd-1'), _sucreSale);
      const List<SaleLineResult> restored = <SaleLineResult>[_sucreRestored];

      catalog.applyCancellation('cmd-1', DateTime(2026, 3, 1, 11), restored);
      catalog.applyCancellation('cmd-1', DateTime(2026, 3, 1, 12), restored);

      expect(catalog.stockOf('sucre'), 10);
    });

    test('ignores a cancellation of a sale it never stored', () {
      final InMemoryProductCatalog catalog = InMemoryProductCatalog(
        <ProductSnapshot>[product('sucre', stock: 10)],
      );

      catalog.applyCancellation('cmd-9', DateTime(2026, 3, 1), const [
        _sucreRestored,
      ]);

      expect(catalog.stockOf('sucre'), 10);
    });
  });
}

CommandContext _context(String commandId) {
  return (
    commandId: commandId,
    dateTime: DateTime(2026, 3, 1),
    source: CommandSource.voice,
  );
}

/// Three sachets of the test product, as a mock handler would have computed it.
const SaleLineResult _sucreSold = (
  productId: 'sucre',
  name: 'sucre',
  unit: 'PIECE',
  qty: 3,
  appliedUnitPrice: 100,
  resultingStock: 7,
);

/// The same three sachets, given back to the stock.
const SaleLineResult _sucreRestored = (
  productId: 'sucre',
  name: 'sucre',
  unit: 'PIECE',
  qty: 3,
  appliedUnitPrice: 100,
  resultingStock: 10,
);

const RecordSaleResult _sucreSale = (
  saleId: 'cmd-1',
  total: 300,
  lines: <SaleLineResult>[_sucreSold],
);
