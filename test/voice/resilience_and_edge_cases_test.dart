import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';

import 'rule_parser_harness.dart';

void main() {
  final RuleParserHarness harness = RuleParserHarness();

  CommandProposal parse(String raw) => harness.parser.parse(raw);

  List<DoubtKind> doubtsOf(String raw) {
    return parse(raw).doubts.map((Doubt d) => d.kind).toList();
  }

  String plain(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : '$value';
  }

  List<String> linesOf(String raw) {
    final CommandProposal proposal = parse(raw);
    final List<ItemMention> items =
        proposal.valueOf<List<ItemMention>>('items') ?? const <ItemMention>[];
    return <String>[
      for (final ItemMention line in items)
        '${line.product.id} x${plain(line.qty)}'
            '${line.spokenAmount == null ? '' : ' a ${plain(line.spokenAmount!)}'}',
    ];
  }

  group('Syntaxe comptoir (post-product counts)', () {
    test('savon deux', () {
      expect(linesOf('vendu savon deux'), <String>['p_savon x2']);
    });

    test('riz cinq kilos', () {
      expect(linesOf('vendu riz cinq kilos'), <String>['p_riz x5']);
    });

    test('savon de menage quatre', () {
      expect(linesOf('vendu savon de menage quatre'), <String>['p_savon x4']);
    });

    test('savon trois morceaux', () {
      expect(linesOf('vendu savon trois morceaux'), <String>['p_savon x3']);
    });
  });

  group('Ordre libre / Inversion (Word order decoupling)', () {
    test('deux savon vendu', () {
      final CommandProposal p = parse('deux savon vendu');
      expect(p.intentId, 'record_sale');
      expect(linesOf('deux savon vendu'), <String>['p_savon x2']);
    });

    test('trois riz recu', () {
      final CommandProposal p = parse('trois riz recu');
      expect(p.intentId, 'record_restock');
      expect(linesOf('trois riz recu'), <String>['p_riz x3']);
    });

    test('trois riz approvisionnement', () {
      final CommandProposal p = parse('trois riz approvisionnement');
      expect(p.intentId, 'record_restock');
      expect(linesOf('trois riz approvisionnement'), <String>['p_riz x3']);
    });

    test('le riz il reste combien', () {
      final CommandProposal p = parse('le riz il reste combien');
      expect(p.intentId, 'query_stock');
      expect(p.valueOf<String>('productId'), 'p_riz');
    });

    test('deux laits ca part', () {
      final CommandProposal p = parse('deux laits ca part');
      expect(p.intentId, 'record_sale');
      expect(linesOf('deux laits ca part'), <String>['p_lait x2']);
    });
  });

  group('Montants directs avec devises', () {
    test('un produit avec quantite et montant en francs', () {
      expect(linesOf('vendu un riz deux mille francs'), <String>[
        'p_riz x1 a 2000',
      ]);
    });

    test('un produit avec quantite et montant en cfa', () {
      expect(linesOf('vendu deux savon 500 cfa'), <String>['p_savon x2 a 500']);
    });

    test('un produit avec quantite et montant en fcfa', () {
      expect(linesOf('vendu un savon 250 fcfa'), <String>['p_savon x1 a 250']);
    });

    test('syntaxe comptoir avec unite et montant en cfa', () {
      expect(linesOf('vendu savon deux morceaux 500 cfa'), <String>[
        'p_savon x2 a 500',
      ]);
    });

    test('syntaxe comptoir avec "a" et cfa', () {
      expect(linesOf('vendu savon deux a 500 cfa'), <String>[
        'p_savon x2 a 500',
      ]);
    });
  });

  group('Distinction Devise vs Quantite', () {
    test(
      'un montant sans quantite explicite compte pour 1 unite au montant annonce',
      () {
        // 2000 est lu comme spokenAmount, PAS comme quantite (x1 a 2000, pas x2000)
        expect(linesOf('vendu du riz pour 2000 francs'), <String>[
          'p_riz x1 a 2000',
        ]);
      },
    );

    test('montant 500 cfa sans quantite explicite', () {
      // 500 est lu comme spokenAmount, PAS comme quantite (x1 a 500, pas x500)
      expect(linesOf('vendu du savon 500 cfa'), <String>['p_savon x1 a 500']);
    });
  });

  group('Multi-lignes et frontieres de produits', () {
    test('deux lignes en syntaxe comptoir: savon deux et lait trois', () {
      expect(linesOf('vendu savon deux et lait trois'), <String>[
        'p_savon x2',
        'p_lait x3',
      ]);
    });

    test('mix avant / apres: deux laits et savon trois', () {
      expect(linesOf('vendu deux laits et savon trois'), <String>[
        'p_lait x2',
        'p_savon x3',
      ]);
    });

    test('produit sans quantite suivi de produit avec quantite', () {
      // "du riz" sans montant ni nombre ne doit pas voler "deux" qui appartient a "sucres"
      expect(linesOf('vendu du riz, deux sucres et trois laits'), <String>[
        'p_sucre x2',
        'p_lait x3',
      ]);
      expect(doubtsOf('vendu du riz, deux sucres et trois laits'), <DoubtKind>[
        DoubtKind.missingQuantity,
      ]);
    });

    test('multi-lignes avec montants et devises respectifs', () {
      expect(
        linesOf('vendu deux savons a 500 francs et un lait a 200 francs'),
        <String>['p_savon x2 a 500', 'p_lait x1 a 200'],
      );
    });
  });

  group('Tolerance Damerau-Levenshtein et fautes de frappe', () {
    test('transposition dans nom de produit: scure -> sucre', () {
      expect(linesOf('vendu deux scures'), <String>['p_sucre x2']);
    });

    test('faute de frappe avec unite: 2 saché de scure', () {
      expect(linesOf('vendu 2 saché de scure'), <String>['p_sucre x2']);
    });
  });
}
