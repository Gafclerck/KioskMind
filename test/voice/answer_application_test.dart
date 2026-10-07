import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/product_name_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/spoken_product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_application.dart';

import 'rule_parser_harness.dart';

/// What an answer does to the proposal the question was asked about.
///
/// This is the logic that lets the session run: without it the app would keep a
/// rule in a measurement tool, and the app would have no way to complete a line the
/// merchant started. The rule is one: an answer fills the doubt it was asked about,
/// keeps everything the merchant already said about that line, and leaves every other
/// doubt standing.
void main() {
  final RuleParserHarness harness = RuleParserHarness();
  final AnswerApplication application = AnswerApplication(
    intents: harness.intents,
    resolver: ProductNameResolver(
      resolver: harness.resolver,
      normalizer: harness.normalizer,
    ),
  );

  CommandProposal parse(String raw) => harness.parser.parse(raw);

  /// The doubt kinds left on the proposal [raw] once the answer has been applied.
  List<DoubtKind> doubtsAfter(String raw, DoubtKind asked, Object? value) {
    return application
        .apply(parse(raw), asked: asked, value: value)
        .doubts
        .map((Doubt doubt) => doubt.kind)
        .toList();
  }

  /// The line the answer produced, as "productId xqty".
  String? lineAfter(String raw, DoubtKind asked, Object? value) {
    final CommandProposal proposal = application.apply(
      parse(raw),
      asked: asked,
      value: value,
    );
    final List<ItemMention> items =
        proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
        const <ItemMention>[];
    if (items.isEmpty) {
      return null;
    }
    final double qty = items.first.qty;
    return '${items.first.product.id} x${qty == qty.roundToDouble() ? qty.toInt() : qty}';
  }

  group('un produit nommé en réponse', () {
    test('complete la ligne et garde le compte déjà dit', () {
      expect(
        lineAfter('vendu deux sachets', DoubtKind.missingProduct, 'sucre'),
        'p_sucre x2',
      );
    });

    test('lève le doute qu il répondait', () {
      expect(
        doubtsAfter('vendu deux sachets', DoubtKind.missingProduct, 'sucre'),
        isEmpty,
      );
    });

    test('porte le produit du slot de l intent, pas celui d un autre', () {
      final CommandProposal answered = application.apply(
        parse('combien il reste de sucre'),
        asked: DoubtKind.missingQuantity,
        value: 2,
      );

      expect(answered.valueOf<String>(kProductIdSlot), 'p_sucre');
    });

    test('un alias se résout comme le nom', () {
      expect(
        lineAfter(
          'vendu deux sachets',
          DoubtKind.missingProduct,
          'sucre en poudre',
        ),
        'p_sucre x2',
      );
    });

    test('un produit déjà résolu est pris tel quel', () {
      final ProductSnapshot sucre = fixtureProducts().firstWhere(
        (ProductSnapshot product) => product.id == 'p_sucre',
      );

      expect(
        lineAfter('vendu deux sachets', DoubtKind.missingProduct, sucre),
        'p_sucre x2',
      );
    });
  });

  group('un compte nommé en réponse', () {
    test('complete la ligne et garde le produit déjà dit', () {
      expect(
        lineAfter('vendu du sucre', DoubtKind.missingQuantity, 3),
        'p_sucre x3',
      );
    });

    test('lève le doute qu il répondait', () {
      expect(
        doubtsAfter('vendu du sucre', DoubtKind.missingQuantity, 3),
        isEmpty,
      );
    });

    test('une quantité en toutes lettres est un nombre, pas un nom', () {
      expect(
        lineAfter('vendu du sucre', DoubtKind.missingQuantity, 0.5),
        'p_sucre x0.5',
      );
    });
  });

  group('une confirmation se répond sans rien nommer', () {
    test('lève les deux doubts confirmants', () {
      expect(
        doubtsAfter(
          'reçu du riz à cinq cent soixante',
          DoubtKind.amountMismatch,
          true,
        ),
        isEmpty,
      );
    });

    test('ne touche à aucun autre doubt', () {
      expect(
        doubtsAfter('approvisionnement', DoubtKind.amountMismatch, true),
        contains(DoubtKind.missingProduct),
      );
    });

    test('enregistre kConfirmedSlot=true quand la confirmation est acceptée', () {
      final CommandProposal proposal = parse('reçu du riz à cinq cent soixante');
      final CommandProposal answered = application.apply(
        proposal,
        asked: DoubtKind.amountMismatch,
        value: true,
      );

      expect(answered.valueOf<bool>(kConfirmedSlot), isTrue);
    });

    test('un refus avec false ne confirme rien et laisse le doute intact', () {
      final CommandProposal proposal = CommandProposal(
        intentId: 'record_sale',
        slots: const <Slot>[],
        doubts: const <Doubt>[Doubt(kind: DoubtKind.amountMismatch)],
        origin: ProposalOrigin.rules,
      );
      final CommandProposal answered = application.apply(
        proposal,
        asked: DoubtKind.amountMismatch,
        value: false,
      );

      expect(answered.valueOf<bool>(kConfirmedSlot), isNull);
      expect(answered.doubts.map((d) => d.kind), contains(DoubtKind.amountMismatch));
    });
  });

  group('ce qu une réponse ne peut pas recevoir', () {
    test('un nom que le catalogue ne connaît pas laisse le doute', () {
      expect(
        doubtsAfter('vendu deux sachets', DoubtKind.missingProduct, 'truc'),
        <DoubtKind>[DoubtKind.missingProduct],
      );
    });

    test('une valeur qui n est ni un nom ni un compte laisse le doute', () {
      expect(
        doubtsAfter('vendu deux sachets', DoubtKind.missingProduct, 3),
        <DoubtKind>[DoubtKind.missingProduct],
      );
      expect(
        doubtsAfter('vendu du sucre', DoubtKind.missingQuantity, 'beaucoup'),
        contains(DoubtKind.missingQuantity),
      );
    });

    test('un produit archivé reste archivé après avoir été nommé', () {
      // Naming the product settles the doubt of the name, never the doubt the
      // catalog raised: a refusal is not a question.
      expect(
        doubtsAfter(
          'vendu deux lait en boite',
          DoubtKind.archivedProduct,
          'lait en boite',
        ),
        contains(DoubtKind.archivedProduct),
      );
    });

    test('un doute absent de la proposition ne crée rien', () {
      expect(
        doubtsAfter('vendu deux sucres', DoubtKind.missingProduct, 'sucre'),
        isEmpty,
      );
    });

    test(
      'une réponse à un doute qui n appelle rien laisse la proposition intacte',
      () {
        final CommandProposal proposal = parse('vendu deux sucres');

        expect(
          application
              .apply(proposal, asked: DoubtKind.anaphora, value: 'le reste')
              .slots,
          proposal.slots,
        );
      },
    );
  });

  List<ItemMention> linesOf(CommandProposal proposal) {
    return proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
        const <ItemMention>[];
  }

  String describeLine(ItemMention line) {
    final double qty = line.qty;
    return '${line.product.id} '
        'x${qty == qty.roundToDouble() ? qty.toInt() : qty}';
  }

  /// The lines the answer produced, as "productId xqty".
  List<String> linesAfter(String raw, DoubtKind asked, Object? value) {
    return linesOf(
      application.apply(parse(raw), asked: asked, value: value),
    ).map(describeLine).toList();
  }

  group('une réponse qui porte sur une ligne précise', () {
    // A doubtful line is never in the list: the extractor leaves it out while it is
    // incomplete. Completing it therefore means adding a line, never overwriting
    // the one that happens to come first. Overwriting it recorded a sale with one
    // article missing and another invented, and nothing in the session said so.
    test(
      'un produit nommé sur la deuxième ligne garde la première intacte',
      () {
        expect(
          linesAfter(
            'vendu deux sucres et de l huile',
            DoubtKind.ambiguousProduct,
            'huile de palme',
          ),
          <String>['p_sucre x2', 'p_huile_palme x1'],
        );
      },
    );

    test('un produit nommé sur la première ligne laisse les deux autres', () {
      expect(
        linesAfter(
          'vendu de l huile, deux sucres et trois laits',
          DoubtKind.ambiguousProduct,
          'huile de palme',
        ),
        <String>['p_sucre x2', 'p_lait x3', 'p_huile_palme x1'],
      );
    });

    test(
      'un compte nommé sur la deuxième ligne ne remplace pas la première',
      () {
        expect(
          linesAfter(
            'vendu deux laits et du sucre',
            DoubtKind.missingQuantity,
            3,
          ),
          <String>['p_lait x2', 'p_sucre x3'],
        );
      },
    );

    test('un compte nommé sur la première ligne garde les deux autres', () {
      expect(
        linesAfter(
          'vendu du sucre, deux laits et trois eaux',
          DoubtKind.missingQuantity,
          3,
        ),
        <String>['p_lait x2', 'p_eau x3', 'p_sucre x3'],
      );
    });

    test('la ligne complétée ne porte pas le montant d une autre', () {
      final CommandProposal answered = application.apply(
        parse('vendu deux sucres a sept cent cinquante et de l huile'),
        asked: DoubtKind.ambiguousProduct,
        value: 'huile de palme',
      );
      final List<ItemMention> items =
          answered.valueOf<List<ItemMention>>(kItemsSlot) ??
          const <ItemMention>[];

      expect(items.map((ItemMention line) => line.spokenAmount), <double?>[
        750,
        null,
      ]);
    });
  });

  group('le port de résolution', () {
    test('le domaine ne devine pas un produit', () {
      final AnswerApplication blind = AnswerApplication(
        intents: harness.intents,
        resolver: const _UnknownResolver(),
      );

      expect(
        blind
            .apply(
              parse('vendu deux sachets'),
              asked: DoubtKind.missingProduct,
              value: 'sucre',
            )
            .doubts
            .map((Doubt doubt) => doubt.kind),
        <DoubtKind>[DoubtKind.missingProduct],
      );
    });
  });
}

/// A resolver that never recognises anything, to prove the domain relies on the
/// port instead of reading the catalog itself.
final class _UnknownResolver implements SpokenProductResolver {
  const _UnknownResolver();

  @override
  ProductSnapshot? resolve(String spokenName) => null;
}
