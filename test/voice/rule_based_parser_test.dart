import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';

import 'rule_parser_harness.dart';

void main() {
  final RuleParserHarness harness = RuleParserHarness();

  CommandProposal parse(String raw) => harness.parser.parse(raw);

  /// The doubts of [raw], in the order the parser raised them.
  List<DoubtKind> doubtsOf(String raw) {
    return parse(raw).doubts.map((Doubt doubt) => doubt.kind).toList();
  }

  /// A quantity as a merchant would read it, without the trailing zero a double
  /// always carries.
  String plain(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : '$value';
  }

  /// The product identifiers and quantities the parser would hand the handler.
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

  group('ce qui est refuse avant meme de lire l intent', () {
    test('une action destructive', () {
      expect(doubtsOf('supprime le produit'), <DoubtKind>[
        DoubtKind.destructiveRequest,
      ]);
      expect(doubtsOf('efface la vente'), <DoubtKind>[
        DoubtKind.destructiveRequest,
      ]);
      expect(doubtsOf('archive le sucre'), <DoubtKind>[
        DoubtKind.destructiveRequest,
      ]);
    });

    test('une commande de commande, inexistante comme use case', () {
      expect(doubtsOf('reçu la commande de ce matin'), <DoubtKind>[
        DoubtKind.noOrderUseCase,
      ]);
    });

    test('une portee non bornee', () {
      expect(doubtsOf('vendu tout'), <DoubtKind>[DoubtKind.unboundedScope]);
      expect(doubtsOf('annule tout'), <DoubtKind>[DoubtKind.unboundedScope]);
    });

    test('"tout a l heure" ne porte pas sur tout', () {
      // C'est un renvoi au passe: le vendeur s'est corrige, la vente reste
      // inexecutee parce que le mot "meme" la rend ambigue, pas "tout".
      expect(
        doubtsOf('vendu le meme sucre que tout a l heure'),
        contains(DoubtKind.anaphora),
      );
      expect(
        doubtsOf('vendu le meme sucre que tout a l heure'),
        isNot(contains(DoubtKind.unboundedScope)),
      );
    });

    test('un refus ne porte aucun intent', () {
      expect(parse('supprime le produit').intentId, kNoIntent);
      expect(parse('quel temps fait-il').intentId, kNoIntent);
    });

    test('une phrase hors commerce', () {
      expect(doubtsOf('quel temps fait-il'), <DoubtKind>[
        DoubtKind.outOfDomain,
      ]);
    });
  });

  group('vente', () {
    test('les lignes dans l ordre parle', () {
      expect(linesOf('vendu deux sucre et un lait'), <String>[
        'p_sucre x2',
        'p_lait x1',
      ]);
    });

    test('le prix annonce reste un doute, pas un argument de vente', () {
      // A7: le prix du catalogue s'applique, le prix parle sert de signal. La
      // ligne le conserve pour le policy, mais les arguments du handler ne le
      // portent pas, sinon le recap afficherait un prix que la vente n'a pas.
      final ItemMention line = parse(
        'vendu un sucre a cent francs',
      ).valueOf<List<ItemMention>>('items')!.single;

      expect(line.spokenAmount, 100);
      expect(line.toArguments('record_sale'), <String, Object?>{
        'productId': 'p_sucre',
        'qty': 1.0,
      });
    });

    test('le meme prix entre dans un approvisionnement', () {
      final ItemMention line = parse(
        'reçu du riz a cinq cent soixante',
      ).valueOf<List<ItemMention>>('items')!.single;

      expect(line.toArguments('record_restock'), <String, Object?>{
        'productId': 'p_riz',
        'qty': 1.0,
        'unitCost': 560.0,
      });
    });

    test('sans quantite, la ligne est une question', () {
      expect(doubtsOf('vendu du sucre'), contains(DoubtKind.missingQuantity));
    });

    test('une quantite nulle est refusee', () {
      expect(doubtsOf('vendu 0 sucre'), <DoubtKind>[DoubtKind.invalidQuantity]);
    });

    test('une question de prix n est pas une vente', () {
      expect(
        doubtsOf('vendu le prix du sucre'),
        contains(DoubtKind.outOfScope),
      );
    });

    test('un produit archive est refuse, pas remplace', () {
      expect(doubtsOf('vendu deux lait en boite'), <DoubtKind>[
        DoubtKind.archivedProduct,
      ]);
    });

    test('un produit inconnu est distingue d un produit absent', () {
      expect(doubtsOf('vendu un truc'), <DoubtKind>[DoubtKind.unknownProduct]);
      expect(doubtsOf('vendu deux sachets'), <DoubtKind>[
        DoubtKind.missingProduct,
      ]);
    });
  });

  group('approvisionnement', () {
    test('le cout annonce fait partie de la commande', () {
      expect(linesOf('reçu du riz a cinq cent soixante'), <String>[
        'p_riz x1 a 560',
      ]);
    });

    test('un cout sans compte vaut une unite', () {
      // "reçu du riz a 560" nomme le produit et son prix: un seul compte rend
      // cette phrase vraie. "vendu du sucre", sans prix, reste une question.
      expect(linesOf('reçu du riz a cinq cent soixante'), <String>[
        'p_riz x1 a 560',
      ]);
      expect(doubtsOf('reçu du riz a cinq cent soixante'), isEmpty);
    });

    test('un compte et un cout ensemble', () {
      expect(
        linesOf('reçu soixante quinze kilos de riz a cinq cent soixante'),
        <String>['p_riz x75 a 560'],
      );
    });
  });

  group('question de stock', () {
    test('le produit suffit, sans quantite', () {
      expect(parse('combien de riz').valueOf<String>('productId'), 'p_riz');
      expect(doubtsOf('combien de riz'), isEmpty);
    });

    test('"reste" y est une question, pas une quantite relative', () {
      expect(
        parse('combien il reste de riz').valueOf<String>('productId'),
        'p_riz',
      );
      expect(doubtsOf('combien il reste de riz'), isEmpty);
    });

    test('sans produit, la question est incomplete', () {
      expect(doubtsOf('combien de sachets'), <DoubtKind>[
        DoubtKind.missingProduct,
      ]);
    });

    test('une question de prix reste une question de prix', () {
      expect(
        parse('combien coute le riz').valueOf<String>('productId'),
        'p_riz',
      );
      expect(doubtsOf('combien coute le riz'), isEmpty);
    });
  });

  group('annulation', () {
    test('porte le placeholder de la session, pas un identifiant', () {
      expect(
        parse('annule la derniere vente').valueOf<String>('saleId'),
        kLastSaleIdPlaceholder,
      );
      expect(doubtsOf('annule la derniere vente'), isEmpty);
    });

    test('un renvoi au passe est une question', () {
      expect(
        doubtsOf('annule la premiere vente'),
        contains(DoubtKind.undeterminedQuantity),
      );
      // "hier" est un mot de quantite relative: la vente designee n est pas
      // designee par son contenu mais par sa date. Le doute est donc celui d une
      // quantite indeterminee, pas celui d un pronom, et la question reste la
      // meme: laquelle?
      expect(doubtsOf("annule la vente d'hier"), <DoubtKind>[
        DoubtKind.undeterminedQuantity,
      ]);
    });
  });

  group('quantite relative', () {
    test('"le reste" sur une vente n est pas un compte', () {
      expect(
        doubtsOf('vendu le reste de sucre'),
        contains(DoubtKind.undeterminedQuantity),
      );
    });

    test('les mots du passe', () {
      expect(
        doubtsOf('vendu le paquet de sucre de la veille'),
        contains(DoubtKind.undeterminedQuantity),
      );
      expect(doubtsOf('stock comme hier'), contains(DoubtKind.anaphora));
    });

    test('"de chaque" et "une autre" designent un produit non dit', () {
      expect(doubtsOf('vendu deux de chaque'), isNotEmpty);
      expect(
        doubtsOf('vendu une biere et une autre'),
        contains(DoubtKind.undeterminedQuantity),
      );
    });
  });

  group('correction en cours de phrase', () {
    test('"non" annule le produit qui vient d etre nomme', () {
      expect(linesOf('j ai vendu deux sucre, attends, non, deux riz'), <String>[
        'p_riz x2',
      ]);
    });

    test('"pas" aussi', () {
      expect(linesOf("j'ai vendu un sucre pas un riz"), <String>['p_riz x1']);
    });

    test('une correction finale retire le dernier produit nomme', () {
      // "non" sans remplacement peut vouloir dire "ne vends rien". Retirer le
      // dernier produit nomme est la lecture qui n execute pas une vente que le
      // commercant vient de retracter; l autre lecture se dit a la question.
      expect(linesOf('vendu un sucre et un riz non'), <String>['p_sucre x1']);
    });
  });

  group('ce que le parseur ne decide pas', () {
    test('une proposition portant un doute n est pas routable', () {
      expect(parse('vendu du sucre').isComplete, isFalse);
      expect(parse('vendu deux savon').isComplete, isTrue);
    });

    test('le verdict n est pas un slot', () {
      final CommandProposal proposal = parse('vendu du sucre');

      expect(
        proposal.slots.map((Slot slot) => slot.name),
        isNot(contains('outcome')),
      );
    });
  });

  group('bruit de reconnaissance vocale', () {
    test('les mots de remplissage disparaissent', () {
      expect(linesOf('bonsoir, euh, vendu une biere'), <String>['p_biere x1']);
    });

    test('une unite mal entendue ne perd pas le compte', () {
      expect(linesOf('vendu 2 saché de sucre'), <String>['p_sucre x2']);
    });

    test('un chatter apres la commande ne cree pas de produit', () {
      expect(linesOf('vendu un cafe, je te raconterai apres'), <String>[
        'p_café x1',
      ]);
      expect(doubtsOf('vendu un cafe, je te raconterai apres'), isEmpty);
    });
  });
}
