import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';

import 'rule_parser_harness.dart';

/// The checks that need the catalog: what the merchant said has to be plausible
/// against what the shop sells.
///
/// A parser cannot do this. "trente sucre" is a perfectly well formed number and
/// an absurd quantity for a shop that sells six a day, and only the catalog knows
/// it.
void main() {
  const VoiceConfig config = VoiceConfig();

  // The validator reads the catalog: which price an announced amount is compared
  // against is declared per intent, not decided by a list of names in the code.
  final IntentCatalog intents = RuleParserHarness().intents;

  final ProductSnapshot sucre = _product(
    id: 'p_sucre',
    price: 100,
    purchasePrice: 75,
    averageDailyQty: 6,
    stock: 40,
  );
  // Prix de vente 100, prix d'achat 60: les deux sont a plus de 20 % l'un de
  // l'autre, donc confondre les deux se voit. Ce sont les valeurs du fixture
  // p_eau.
  final ProductSnapshot eau = _product(
    id: 'p_eau',
    price: 100,
    purchasePrice: 60,
    averageDailyQty: 20,
    stock: 240,
  );

  CommandProposal proposalFor(String intent, List<ItemMention> items) =>
      CommandProposal(
        intentId: intent,
        slots: <Slot>[Slot(name: 'items', value: items)],
        doubts: const <Doubt>[],
        origin: ProposalOrigin.rules,
      );

  ItemMention line(ProductSnapshot product, double qty, {double? amount}) =>
      ItemMention(product: product, qty: qty, spokenAmount: amount);

  List<DoubtKind> doubtsOf(
    String intent,
    List<ItemMention> items, {
    VoiceConfig? withConfig,
  }) {
    return CommandValidator(
      config: withConfig ?? config,
      intents: intents,
    ).validate(proposalFor(intent, items)).map((Doubt d) => d.kind).toList();
  }

  group('ce qui ne se doute de rien', () {
    test('une ligne ordinaire ne leve aucun doute', () {
      expect(doubtsOf('record_sale', <ItemMention>[line(sucre, 2)]), isEmpty);
      expect(
        doubtsOf('record_restock', <ItemMention>[line(sucre, 2, amount: 75)]),
        isEmpty,
      );
    });

    test('le prix de catalogue parle ne leve aucun doute', () {
      // 100 francs le kilo du sucre, c'est le prix du catalogue: rien a dire.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 1, amount: 100)]),
        isEmpty,
      );
      expect(
        doubtsOf('record_restock', <ItemMention>[line(sucre, 1, amount: 75)]),
        isEmpty,
      );
    });

    test('un ecart de prix dans la tolerance ne leve aucun doute', () {
      // La tolerance est inclusive: 20 % pile, c'est encore le prix du catalogue
      // aux yeux du module. Mesure sur le jeu fige, cas t122.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 1, amount: 120)]),
        isEmpty,
      );
    });

    test('une quantite ordinaire ne leve aucun doute', () {
      expect(doubtsOf('record_sale', <ItemMention>[line(sucre, 20)]), isEmpty);
    });
  });

  group('ecart de prix', () {
    test('au dela de la tolerance, le prix est doute', () {
      // Mesure sur le jeu fige: 43 % et plus sont des confirmations, 20 % pile
      // est une execution.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 1, amount: 150)]),
        <DoubtKind>[DoubtKind.amountMismatch],
      );
    });

    test('la reference est le prix de vente sur une vente', () {
      // 60 est le prix d'achat de l'eau, pas son prix de vente: le confondre est
      // une erreur du marchand, donc un doute.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(eau, 1, amount: 60)]),
        <DoubtKind>[DoubtKind.amountMismatch],
      );
    });

    test('la reference est le prix d achat sur un approvisionnement', () {
      // Le meme chiffre sur un approvisionnement est le bon prix d'achat, et le
      // prix de vente y devient l'ecart.
      expect(
        doubtsOf('record_restock', <ItemMention>[line(eau, 1, amount: 60)]),
        isEmpty,
      );
      expect(
        doubtsOf('record_restock', <ItemMention>[line(eau, 1, amount: 100)]),
        <DoubtKind>[DoubtKind.amountMismatch],
      );
    });

    test('un produit sans prix ne se compare a rien', () {
      final ProductSnapshot gratuit = _product(
        id: 'p_gratuit',
        price: 0,
        purchasePrice: null,
        averageDailyQty: 1,
        stock: 0,
      );

      expect(
        doubtsOf('record_sale', <ItemMention>[line(gratuit, 1, amount: 500)]),
        isEmpty,
      );
    });
  });

  group('quantite habituelle', () {
    test('au dela du seuil du magasin, la quantite est doute', () {
      // Le seuil est calibre sur le jeu fige: au dela de 20 unites d un coup,
      // le module demande confirmation. 30 sucres sur 6 par jour, c'est 5 fois
      // le rythme du magasin.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 30)]),
        <DoubtKind>[DoubtKind.implausibleQuantity],
      );
    });

    test('le seuil est une configuration, pas une constante dans le code', () {
      expect(
        doubtsOf('record_sale', <ItemMention>[
          line(sucre, 30),
        ], withConfig: config.copyWith(unusualQuantityThreshold: 40)),
        isEmpty,
        reason: 'un seuil plus haut accepte 30, sans toucher au test',
      );
      expect(
        doubtsOf('record_sale', <ItemMention>[
          line(sucre, 10),
        ], withConfig: config.copyWith(unusualQuantityThreshold: 5)),
        <DoubtKind>[DoubtKind.implausibleQuantity],
      );
    });

    test('le doute porte sur le slot des lignes', () {
      final List<Doubt> doubts = CommandValidator(
        config: config,
        intents: intents,
      ).validate(proposalFor('record_sale', <ItemMention>[line(sucre, 30)]));

      expect(doubts.single.slotName, 'items');
    });

    test('chaque ligne fautive compte pour une', () {
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 2), line(eau, 30)]),
        <DoubtKind>[DoubtKind.implausibleQuantity],
      );
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 30), line(eau, 40)]),
        <DoubtKind>[
          DoubtKind.implausibleQuantity,
          DoubtKind.implausibleQuantity,
        ],
      );
    });
  });

  group('plafond du magasin', () {
    test(
      'au dela du plafond, la quantite est invalide et non seulement doute',
      () {
        // Un nombre au dela de ce qu un magasin peut vendre d un coup n est pas une
        // quantite, c est une erreur de reconnaissance: le refuser est la seule
        // reponse honnete.
        expect(
          doubtsOf('record_sale', <ItemMention>[line(sucre, 1001)]),
          <DoubtKind>[DoubtKind.invalidQuantity],
        );
      },
    );

    test('le plafond lui-meme reste une quantite inhabituelle', () {
      // 1000 unites est mesure sur le jeu fige (cas t112) et attendu comme
      // confirmation, pas comme refus: la borne est stricte.
      expect(
        doubtsOf('record_sale', <ItemMention>[line(sucre, 1000)]),
        <DoubtKind>[DoubtKind.implausibleQuantity],
      );
    });

    test(
      'un prix doute et une quantite invalide se disent toutes les deux',
      () {
        expect(
          doubtsOf('record_sale', <ItemMention>[
            line(sucre, 1001, amount: 900),
          ]),
          <DoubtKind>[DoubtKind.invalidQuantity, DoubtKind.amountMismatch],
        );
      },
    );
  });

  group('propositions sans ligne', () {
    test('une lecture de stock n est pas validee comme une vente', () {
      expect(
        CommandValidator(
          config: config,
          intents: intents,
        ).validate(proposalFor('query_stock', const <ItemMention>[])),
        isEmpty,
      );
    });

    test('une proposition sans slot articles ne leve rien', () {
      expect(
        CommandValidator(config: config, intents: intents).validate(
          const CommandProposal(
            intentId: 'record_sale',
            slots: <Slot>[],
            doubts: <Doubt>[],
            origin: ProposalOrigin.rules,
          ),
        ),
        isEmpty,
      );
    });

    test('une proposition deja douteuse garde ses doutes', () {
      // Le validateur ajoute, il ne remplace pas: la sortie du parseur fait
      // autorite et le dialogue a besoin de la voir entiere.
      final CommandProposal refused = CommandProposal(
        intentId: 'record_sale',
        slots: <Slot>[
          Slot(name: 'items', value: <ItemMention>[line(sucre, 30)]),
        ],
        doubts: const <Doubt>[Doubt(kind: DoubtKind.archivedProduct)],
        origin: ProposalOrigin.rules,
      );

      expect(
        CommandValidator(
          config: config,
          intents: intents,
        ).validate(refused).map((Doubt d) => d.kind),
        <DoubtKind>[DoubtKind.implausibleQuantity],
        reason: 'le validateur ne rend que ses propres doutes',
      );
      expect(refused.hasDoubt(DoubtKind.archivedProduct), isTrue);
    });
  });
}

ProductSnapshot _product({
  required String id,
  required double price,
  required double? purchasePrice,
  required double averageDailyQty,
  required double stock,
}) {
  return ProductSnapshot(
    id: id,
    name: id,
    aliases: const <String>[],
    unit: 'UNIT',
    price: price,
    purchasePrice: purchasePrice,
    stock: stock,
    alertThreshold: 0,
    averageDailyQty: averageDailyQty,
  );
}
