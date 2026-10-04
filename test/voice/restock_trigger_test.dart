import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';

import 'rule_parser_harness.dart';

void main() {
  group('RuleBasedParser restock triggers', () {
    late RuleParserHarness harness;

    setUp(() {
      harness = RuleParserHarness();
    });

    final List<String> restockPhrases = <String>[
      'reçu du riz a cinq cent soixante',
      'reçu dix sucres',
      'reçu 10 sucres',
      "j'ai reçu 10 sucres",
      'ajoute 10 sucres',
      'ajouter 10 sucres',
      'rajoute 10 sucres',
      'ajoute au stock 10 sucres',
      'approvisionnement 10 sucres',
      'approvisionne 10 sucres',
      'reapprovisionnement 10 sucres',
      'reappro 10 sucres',
      'restock 10 sucres',
      'entrée de stock 10 sucres',
      'achat de 10 sucres',
      "j'ai acheté 10 sucres",
      'j ai rentre 10 sucres',
      'livraison 10 sucres',
      'reassort 10 sucres',
    ];

    for (final String phrase in restockPhrases) {
      test('parses "$phrase" as record_restock without rejection', () {
        final CommandProposal proposal = harness.parser.parse(phrase);
        expect(
          proposal.intentId,
          equals('record_restock'),
          reason: 'Failed to recognize restock intent for "$phrase"',
        );
        expect(
          proposal.doubts,
          isEmpty,
          reason: 'Unexpected doubts for "$phrase"',
        );

        final List<ItemMention>? items = proposal.valueOf<List<ItemMention>>(
          'items',
        );
        expect(items, isNotNull, reason: 'No items extracted for "$phrase"');
        expect(items, isNotEmpty, reason: 'Items list empty for "$phrase"');
      });
    }
  });
}
