import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';

import 'rule_parser_harness.dart';

/// Une commande se lit dans le catalogue, pas dans le code du parseur.
///
/// Le catalogue décrit deja chaque commande : son risque et la forme de ses slots. Un
/// parseur qui compare des chaines d'identifiants doit etre modifie a chaque ajout de
/// commande, et c'est exactement ce que le contrat du module refuse. Ces tests le
/// prennent sur le fait, avec des commandes que le code livre ne connait pas.
void main() {
  test('une commande declaree en lecture ne demande pas de quantite', () {
    // "peremption du sucre" ne porte aucune quantite. La commande est declaree en
    // lecture, donc l'absence de quantite n'est pas un doute: le parseur le sait en
    // regardant le risque declare, pas en comptant les commandes qu'il connait.
    final CommandProposal proposal = _parserWith(_checkExpiry()).parse(
      'peremption du sucre',
    );

    expect(proposal.intentId, 'check_expiry');
    expect(proposal.doubts, isEmpty);
    expect(
      proposal.valueOf<String>(kProductIdSlot),
      'p_sucre',
      reason: 'le slot declare est un produit, pas une liste de lignes',
    );
    expect(
      proposal.valueOf<List<Object?>>(kItemsSlot),
      isNull,
      reason: 'une commande qui ne declare pas de liste n en recoit pas une',
    );
  });

  test('une commande declaree en ecriture exige une quantite', () {
    // La meme phrase, une commande qui declare une liste de lignes et le risque
    // d'ecriture: sans quantite, la ligne est douteuse et rien ne s execute.
    final CommandProposal proposal = _parserWith(_countLines()).parse(
      'comptage du sucre',
    );

    expect(proposal.intentId, 'count_lines');
    expect(proposal.hasDoubt(DoubtKind.missingQuantity), isTrue);
  });

  test('le prix de reference d une ecriture est declare dans le catalogue', () {
    // Le validateur compare un montant annonce a un prix du produit. Lequel des deux
    // prix compte est une donnee du catalogue, pas une comparaison d'identifiant.
    final IntentCatalog catalog = parseIntentCatalog(
      File(intentCatalogAsset).readAsStringSync(),
    );

    expect(catalog.byId('record_sale')!.referencePrice.code, 'sale_price');
    expect(
      catalog.byId('record_restock')!.referencePrice.code,
      'purchase_price',
    );
    expect(catalog.byId('query_stock')!.referencePrice.code, 'none');
  });
}

/// A parser over the shipped catalog plus one command the shipped code never heard of.
RuleBasedParser _parserWith(IntentDefinition extra) {
  final RuleParserHarness harness = RuleParserHarness();
  final IntentDefinition one = extra;
  return RuleBasedParser(
    normalizer: harness.normalizer,
    detector: IntentDetector(
      catalog: IntentCatalog(
        currency: harness.intents.currency,
        intents: <IntentDefinition>[...harness.intents.intents, one],
      ),
      normalizer: harness.normalizer,
    ),
    items: ItemListExtractor(resolver: harness.resolver, lines: harness.lines),
    config: harness.config,
  );
}

/// A read command about one product, of a shape the catalog already describes.
IntentDefinition _checkExpiry() {
  return _intent(
    id: 'check_expiry',
    risk: IntentRisk.read,
    trigger: 'peremption',
    slots: <SlotDefinition>[
      SlotDefinition(
        name: 'productName',
        type: SlotType.productName,
        required: true,
        description: 'Produit dont la peremption est demandee.',
        lineSlots: const <SlotDefinition>[],
      ),
    ],
  );
}

/// A write command about a list of lines, of the shape of a sale.
IntentDefinition _countLines() {
  return _intent(
    id: 'count_lines',
    risk: IntentRisk.writeReversible,
    trigger: 'comptage',
    slots: <SlotDefinition>[
      SlotDefinition(
        name: 'items',
        type: SlotType.itemList,
        required: true,
        description: 'Lignes a compter.',
        lineSlots: <SlotDefinition>[
          SlotDefinition(
            name: 'productName',
            type: SlotType.productName,
            required: true,
            description: 'Produit compte.',
            lineSlots: const <SlotDefinition>[],
          ),
          SlotDefinition(
            name: 'qty',
            type: SlotType.quantity,
            required: true,
            description: 'Quantite comptee.',
            lineSlots: const <SlotDefinition>[],
          ),
        ],
      ),
    ],
  );
}

IntentDefinition _intent({
  required String id,
  required IntentRisk risk,
  required String trigger,
  required List<SlotDefinition> slots,
}) {
  return IntentDefinition(
    id: id,
    handler: id,
    risk: risk,
    description: 'Commande declaree par un test, inconnue du code livre.',
    triggers: <String>[trigger],
    examples: <String>['$trigger du sucre'],
    slots: slots,
  );
}