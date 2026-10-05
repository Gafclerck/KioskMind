import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/registry/kiosk_registry.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/registry/kiosk_tool_spec.dart';

/// What the language model is told the shop can do.
///
/// The registry has no list of commands of its own: it reads the catalog that ships
/// with the app. These tests are therefore about the projection, and the strongest
/// thing they can assert is that nothing is lost between the JSON and the prompt.
/// The one thing they must also assert is that adding an intent to the catalog
/// changes the prompt, because that is the whole reason the second copy of the list
/// is gone.
void main() {
  final IntentCatalog catalog = parseIntentCatalog(
    File(intentCatalogAsset).readAsStringSync(),
  );
  final KioskRegistry registry = KioskRegistry.fromCatalog(catalog);

  group('KioskRegistry projeté depuis le catalogue', () {
    test('expose une commande par identifiant, dans l\'ordre du catalogue', () {
      expect(
        registry.allTools().map((KioskToolSpec t) => t.name).toList(),
        catalog.ids,
      );
      expect(registry.allTools(), hasLength(14));

      for (final String id in catalog.ids) {
        expect(registry.get(id), isNotNull, reason: 'Commande absente : $id');
      }
      expect(registry.get('record_client_debt'), isNull);
    });

    test('ne se modifie pas : la liste renvoyée est une copie', () {
      final List<KioskToolSpec> tools = registry.allTools();
      expect(() => tools.removeLast(), throwsUnsupportedError);
    });

    test('porte la description et l\'exemple du catalogue, sans les recopier', () {
      final KioskToolSpec sale = registry.get('record_sale')!;
      final IntentDefinition intent = catalog.byId('record_sale')!;

      expect(sale.label, intent.description);
      expect(sale.example, intent.examples.first);
      expect(sale.label, isNotEmpty);
    });

    test('décrit les emplacements du catalogue dans le prompt de réponse', () {
      final String format = registry.toResponseFormatPrompt();

      expect(format, contains("Pour 'record_sale'"));
      expect(format, contains('"productId"'));
      expect(format, contains('"spokenUnitPrice"'));
      expect(format, contains('"qty"'));
      // Une commande sans emplacement ne propose que son identifiant.
      expect(format, contains('{"intentId": "cancel_last_sale"}'));
    });

    test('respecte le caractère obligatoire de chaque emplacement', () {
      final String format = registry.toResponseFormatPrompt();
      final int saleAt = format.indexOf("Pour 'record_sale'");
      final String saleBlock = format.substring(saleAt, saleAt + 400);

      // Obligatoires : le produit et la quantité, montrés seuls.
      expect(saleBlock, contains('"productId": "<id_catalogue>"'));
      expect(saleBlock, contains('"qty": 0,'));
      expect(saleBlock, isNot(contains('"qty": 0 /* optionnel */')));
      // Optionnels : annoncés, mais marqués comme tels, ligne comprise.
      expect(saleBlock, contains('"unit": "..." /* optionnel */'));
      expect(saleBlock, contains('"spokenUnitPrice": 0 /* optionnel */'));
    });

    test('nomme dans la règle D5 les seules commandes qui visent un produit', () {
      final String prompt = registry.buildSystemPrompt();
      final String rule = prompt.substring(
        prompt.indexOf("RÈGLE D'ANCRAGE STRICTE"),
        prompt.indexOf('FORMAT DE RÉPONSE'),
      );

      for (final String id in <String>[
        'record_sale',
        'record_restock',
        'query_stock',
        'query_product_price',
        'record_stock_out',
        'update_product_price',
      ]) {
        expect(rule, contains("'$id'"), reason: '$id doit être ancré');
      }
      for (final String id in <String>[
        'cancel_last_sale',
        'navigate_to_page',
        'export_sales_report',
        'query_business_info',
        'create_product',
      ]) {
        expect(rule, isNot(contains("'$id'")), reason: '$id ne vise aucun produit');
      }
    });

    test('construit un prompt qui pose les trois règles, sans liste figée', () {
      final String prompt = registry.buildSystemPrompt();

      expect(prompt, startsWith("Tu es l'assistant de caisse de KioskMind"));
      expect(prompt, contains("RÈGLE D'ANCRAGE STRICTE (D5)"));
      expect(prompt, contains("FORMAT DE RÉPONSE OBLIGATOIRE EN JSON PUR"));

      for (final String id in catalog.ids) {
        expect(
          prompt,
          contains("- '$id' :"),
          reason: 'Commande absente du prompt : $id',
        );
        expect(prompt, contains("Pour '$id'"));
      }
    });

    test('ajouter une intention au catalogue suffit à la publier', () {
      final IntentDefinition added = IntentDefinition(
        id: 'record_client_debt',
        handler: 'record_client_debt',
        risk: IntentRisk.writeReversible,
        description: "Enregistrer une dette client",
        triggers: <String>['doit', 'dette'],
        examples: <String>['amadou me doit cinq mille francs'],
        slots: const <SlotDefinition>[
          SlotDefinition(
            name: 'clientName',
            type: SlotType.string,
            required: true,
            description: 'Nom du client',
            lineSlots: <SlotDefinition>[],
          ),
          SlotDefinition(
            name: 'amount',
            type: SlotType.money,
            required: true,
            description: 'Montant dû',
            lineSlots: <SlotDefinition>[],
          ),
        ],
      );
      final KioskRegistry extended = KioskRegistry.fromCatalog(
        IntentCatalog(
          currency: catalog.currency,
          intents: <IntentDefinition>[...catalog.intents, added],
        ),
      );

      final String prompt = extended.buildSystemPrompt();
      expect(extended.allTools(), hasLength(15));
      expect(prompt, contains("- 'record_client_debt' : Enregistrer une dette"));
      expect(prompt, contains('"clientName": "..."'));
      expect(prompt, contains('"amount": 0'));
    });
  });

  group('déclaration de fonction', () {
    test('reprend les types et les obligatoires des emplacements', () {
      final Map<String, dynamic> declaration = registry
          .get('update_product_price')!
          .toFunctionDeclaration();
      final Map<String, dynamic> parameters =
          declaration['parameters'] as Map<String, dynamic>;

      expect(declaration['name'], equals('update_product_price'));
      expect(
        declaration['description'] as String,
        contains(catalog.byId('update_product_price')!.examples.first),
      );
      expect(parameters['required'], <String>['productId', 'newPrice']);

      final Map<String, dynamic> properties =
          parameters['properties'] as Map<String, dynamic>;
      expect(
        (properties['productId'] as Map<String, dynamic>)['type'],
        equals('string'),
      );
      expect(
        (properties['newPrice'] as Map<String, dynamic>)['type'],
        equals('number'),
      );
    });

    test('développe une liste d\'articles en tableau d\'objets', () {
      final Map<String, dynamic> declaration = registry
          .get('record_sale')!
          .toFunctionDeclaration();
      final Map<String, dynamic> parameters =
          declaration['parameters'] as Map<String, dynamic>;
      final Map<String, dynamic> items =
          (parameters['properties'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final Map<String, dynamic> line = items['items'] as Map<String, dynamic>;

      expect(items['type'], equals('array'));
      expect(line['type'], equals('object'));
      expect(
        (line['properties'] as Map<String, dynamic>).keys.toList(),
        <String>['productId', 'qty', 'unit', 'spokenUnitPrice'],
      );
      expect(line['required'], <String>['productId', 'qty']);
    });

    test('donne une déclaration par commande, dans l\'ordre du catalogue', () {
      final List<Map<String, dynamic>> tools = registry.toGeminiTools();

      expect(
        tools.map((Map<String, dynamic> t) => t['name']).toList(),
        catalog.ids,
      );
      for (final Map<String, dynamic> tool in tools) {
        expect(tool['description'], isNotEmpty);
        expect(
          (tool['parameters'] as Map<String, dynamic>)['properties'],
          isA<Map<String, dynamic>>(),
        );
      }
    });
  });
}
