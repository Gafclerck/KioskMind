import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

/// The catalog shipped with the app, as a string, so the tests below can break
/// it in one place at a time.
const String valid = '''
{
  "version": 1,
  "currency": "XOF",
  "intents": [
    {
      "id": "record_sale",
      "handler": "record_sale",
      "risk": "WRITE_REVERSIBLE",
      "description": "Enregistrer une vente.",
      "triggers": ["vendu", "je vends"],
      "examples": ["vendu deux sucre"],
      "slots": [
        {
          "name": "items",
          "type": "item_list",
          "required": true,
          "description": "Lignes de la vente.",
          "lineSlots": [
            {
              "name": "productName",
              "type": "product_name",
              "required": true,
              "description": "Nom prononce."
            },
            {
              "name": "qty",
              "type": "quantity",
              "required": true,
              "description": "Quantite vendue."
            }
          ]
        }
      ]
    },
    {
      "id": "record_restock",
      "handler": "record_restock",
      "risk": "WRITE_REVERSIBLE",
      "description": "Enregistrer un approvisionnement.",
      "triggers": ["recu"],
      "examples": ["recu dix cartons de lait"],
      "slots": [
        {
          "name": "items",
          "type": "item_list",
          "required": true,
          "description": "Lignes de l approvisionnement.",
          "lineSlots": [
            {
              "name": "productName",
              "type": "product_name",
              "required": true,
              "description": "Nom prononce."
            },
            {
              "name": "qty",
              "type": "quantity",
              "required": true,
              "description": "Quantite recue."
            }
          ]
        }
      ]
    },
    {
      "id": "query_stock",
      "handler": "query_stock",
      "risk": "READ",
      "description": "Consulter un stock.",
      "triggers": ["stock de"],
      "examples": ["stock du sucre"],
      "slots": [
        {
          "name": "productName",
          "type": "product_name",
          "required": true,
          "description": "Nom du produit.",
          "lineSlots": []
        }
      ]
    },
    {
      "id": "cancel_last_sale",
      "handler": "cancel_last_sale",
      "risk": "WRITE_REVERSIBLE",
      "description": "Annuler la derniere vente.",
      "triggers": ["annule"],
      "examples": ["annule la derniere vente"],
      "slots": []
    }
  ]
}
''';

/// The catalog as the app reads it at runtime, through the asset bundle.
late final String shipped;

void main() {
  // The shipped catalog is an asset, which needs the test binding to be read.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseIntentCatalog', () {
    test('reads a well-formed catalog', () {
      final IntentCatalog catalog = parseIntentCatalog(valid);

      expect(catalog.currency, 'XOF');
      expect(catalog.ids, <String>[
        'record_sale',
        'record_restock',
        'query_stock',
        'cancel_last_sale',
      ]);
    });

    test('exposes the risk and the write nature of each intent', () {
      final IntentCatalog catalog = parseIntentCatalog(valid);

      expect(catalog.byId('query_stock')?.risk, IntentRisk.read);
      expect(catalog.byId('query_stock')?.risk.isWrite, isFalse);
      expect(catalog.byId('record_sale')?.risk, IntentRisk.writeReversible);
      expect(catalog.byId('record_sale')?.risk.isWrite, isTrue);
      expect(catalog.byId('inconnu'), isNull);
    });

    test('describes the line slots of an item list', () {
      final IntentDefinition sale = parseIntentCatalog(
        valid,
      ).byId('record_sale')!;

      expect(sale.slots, hasLength(1));
      final SlotDefinition items = sale.slots.single;
      expect(items.type, SlotType.itemList);
      expect(items.isItemList, isTrue);
      expect(items.required, isTrue);
      expect(
        items.lineSlots.map((SlotDefinition s) => s.name).toList(),
        <String>['productName', 'qty'],
      );
      expect(items.lineSlots.first.type, SlotType.productName);
    });

    test('keeps triggers and examples apart', () {
      final IntentDefinition query = parseIntentCatalog(
        valid,
      ).byId('query_stock')!;

      expect(query.triggers, <String>['stock de']);
      expect(query.examples, <String>['stock du sucre']);
      expect(query.slots.single.lineSlots, isEmpty);
    });

    test('refuses an intent no port can execute', () {
      final String broken = valid.replaceFirst(
        '"id": "query_stock"',
        '"id": "delete_everything"',
      );

      expect(
        () => parseIntentCatalog(broken),
        throwsA(isA<FormatException>()),
        reason: 'le catalogue ne peut pas decrire une commande sans handler',
      );
    });

    test('refuses a port that the catalog never describes', () {
      final String broken = valid.replaceFirst(
        '    {\n      "id": "record_restock"',
        '    ',
      );

      expect(
        () => parseIntentCatalog(broken),
        throwsA(isA<FormatException>()),
        reason: 'un port sans entree de catalogue n est plus atteignable',
      );
    });

    test('refuses an intent whose handler does not match its id', () {
      final String broken = valid.replaceFirst(
        '"handler": "query_stock"',
        '"handler": "record_sale"',
      );

      expect(() => parseIntentCatalog(broken), throwsA(isA<FormatException>()));
    });

    test('refuses a duplicated intent', () {
      final String broken = valid.replaceFirst(
        '"id": "cancel_last_sale"',
        '"id": "record_sale"',
      );

      expect(() => parseIntentCatalog(broken), throwsA(isA<FormatException>()));
    });

    test('refuses a risk class that does not exist', () {
      for (final String risk in <String>['DESTRUCTIVE', 'read', 'supprimer']) {
        expect(
          () => parseIntentCatalog(
            valid.replaceFirst('"risk": "READ"', '"risk": "$risk"'),
          ),
          throwsA(isA<FormatException>()),
          reason: risk,
        );
      }
    });

    test('refuses a slot type outside the closed set', () {
      final String broken = valid.replaceFirst(
        '"type": "quantity"',
        '"type": "product_id"',
      );

      expect(() => parseIntentCatalog(broken), throwsA(isA<FormatException>()));
    });

    test('refuses an item list without its line slots', () {
      for (final String lines in <String>[
        '',
        '"lineSlots": []',
        '"lineSlots": {}',
      ]) {
        expect(
          () => parseIntentCatalog(
            valid.replaceFirst(
              RegExp(r'"lineSlots": \[\s*\{.*?\}\s*\]', dotAll: true),
              lines.isEmpty ? '"lineSlots": []' : lines,
            ),
          ),
          throwsA(isA<FormatException>()),
          reason: lines,
        );
      }
    });

    test('refuses line slots on a slot that is not a list', () {
      final String broken = valid.replaceFirst(
        '"description": "Nom du produit.",\n          "lineSlots": []',
        '"description": "Nom du produit.",\n          "lineSlots": [\n'
            '            {"name": "qty", "type": "quantity", "required": true, '
            '"description": "Quantite."}\n          ]',
      );

      expect(
        () => parseIntentCatalog(broken),
        throwsA(isA<FormatException>()),
        reason: 'le schema doit dire la forme du slot, sans ambiguite',
      );
    });

    test('refuses a trigger that is not normalized', () {
      expect(
        () => parseIntentCatalog(
          valid.replaceFirst(
            '"triggers": ["stock de"]',
            '"triggers": ["Stock de"]',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseIntentCatalog(
          valid.replaceFirst(
            '"triggers": ["stock de"]',
            '"triggers": ["stock dé"]',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses an empty or duplicated trigger or example', () {
      for (final String list in <String>[
        '"triggers": []',
        '"triggers": ["stock de", "stock de"]',
        '"triggers": ["  "]',
        '"examples": []',
        '"examples": ["stock du sucre", "stock du sucre"]',
      ]) {
        // '"triggers": [...]' -> the key to look for in the fixture.
        final String key = list.substring(1, list.indexOf(':') - 1);
        expect(
          () => parseIntentCatalog(
            valid.replaceFirst(RegExp('"$key": \\[[^\\]]*\\]'), list),
          ),
          throwsA(isA<FormatException>()),
          reason: list,
        );
      }
    });

    test('refuses a missing or blank required field', () {
      final List<String> brokenCatalogs = <String>[
        valid.replaceFirst('"version": 1,', ''),
        valid.replaceFirst('"currency": "XOF"', '"currency": "  "'),
        valid.replaceFirst('"intents": [', '"intents": {}, '),
        valid.replaceFirst(RegExp(r'"triggers": \["vendu", "je vends"\],'), ''),
        valid.replaceFirst(RegExp(r'"examples": \["vendu deux sucre"\],'), ''),
        valid.replaceFirst('"description": "Consulter un stock.",', ''),
        valid.replaceFirst(
          '"required": true,\n          "description": "Nom du produit."',
          '"description": "Nom du produit."',
        ),
        valid.replaceFirst('"type": "item_list",', '"type": 12,'),
      ];

      for (final String broken in brokenCatalogs) {
        expect(
          () => parseIntentCatalog(broken),
          throwsA(isA<FormatException>()),
          reason: broken.length > 60 ? '${broken.substring(0, 60)}...' : broken,
        );
      }
    });

    test('refuses an empty intent list and a non-object root', () {
      expect(
        () => parseIntentCatalog(
          '{"version": 1, "currency": "XOF", "intents": []}',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(() => parseIntentCatalog('[]'), throwsA(isA<FormatException>()));
      expect(() => parseIntentCatalog('{'), throwsA(isA<FormatException>()));
    });
  });

  group('the catalog shipped with the app', () {
    // Read through the asset bundle on purpose: a catalog that parses in the
    // test but is not declared in `pubspec.yaml` would fail only at runtime.
    setUpAll(() async {
      shipped = await rootBundle.loadString(intentCatalogAsset);
    });

    test('validates', () {
      expect(parseIntentCatalog(shipped).ids, hasLength(4));
    });

    test('declares one handler per port, and the handler matches the id', () {
      final IntentCatalog catalog = parseIntentCatalog(shipped);

      expect(catalog.ids.toSet(), kSupportedIntentIds);
      for (final IntentDefinition intent in catalog.intents) {
        expect(intent.handler, intent.id);
      }
    });

    test('gives every intent at least one trigger and one example', () {
      for (final IntentDefinition intent in parseIntentCatalog(
        shipped,
      ).intents) {
        expect(intent.triggers, isNotEmpty, reason: intent.id);
        expect(intent.examples, isNotEmpty, reason: intent.id);
      }
    });

    test('exposes a money slot exactly where a price can be spoken', () {
      final IntentCatalog catalog = parseIntentCatalog(shipped);
      List<String> lineNames(String intentId) => <String>[
        for (final SlotDefinition slot in catalog.byId(intentId)!.slots)
          for (final SlotDefinition line in slot.lineSlots) line.name,
      ];

      expect(lineNames('record_sale'), contains('unitPrice'));
      expect(lineNames('record_restock'), contains('unitCost'));
      expect(
        catalog.byId('cancel_last_sale')!.slots,
        isEmpty,
        reason: 'une annulation ne porte aucun slot (arbitrage A12)',
      );
    });

    test(
      'keeps every product slot optional except the name and the quantity',
      () {
        final IntentCatalog catalog = parseIntentCatalog(shipped);

        for (final String intentId in <String>[
          'record_sale',
          'record_restock',
        ]) {
          final List<SlotDefinition> lines = catalog
              .byId(intentId)!
              .slots
              .single
              .lineSlots;
          for (final SlotDefinition line in lines) {
            expect(
              line.required,
              line.name == 'productName' || line.name == 'qty',
              reason: '$intentId.${line.name}',
            );
          }
        }
      },
    );
  });
}
