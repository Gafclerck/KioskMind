import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';

/// Covers the value objects the whole module passes around.
///
/// A proposal is read by the decision policy, compared by the tests and printed
/// in a failure message; nothing here is business logic, but each method is the
/// place where a mistake would stay invisible until a later phase.
void main() {
  const Slot product = Slot(name: 'productId', value: 'p_riz');
  const Slot qty = Slot(name: 'qty', value: 2.0);

  CommandProposal sale({
    List<Slot> slots = const <Slot>[product, qty],
    List<Doubt> doubts = const <Doubt>[],
    ProposalOrigin origin = ProposalOrigin.rules,
  }) {
    return CommandProposal(
      intentId: 'record_sale',
      slots: slots,
      doubts: doubts,
      origin: origin,
    );
  }

  group('valueOf', () {
    test('renvoie la valeur du slot demande', () {
      expect(sale().valueOf<String>('productId'), 'p_riz');
      expect(sale().valueOf<double>('qty'), 2.0);
    });

    test('un slot absent ne vaut pas une valeur', () {
      expect(sale().valueOf<String>('unitCost'), isNull);
    });

    test('un slot lu avec le mauvais type ne vaut pas une valeur', () {
      // "qty" est un double: le lire comme un String doit echouer proprement,
      // jamais renvoyer la valeur_string de la meme valeur.
      expect(sale().valueOf<String>('qty'), isNull);
      expect(sale().valueOf<int>('qty'), isNull);
    });

    test('un slot sans valeur ne vaut pas une valeur', () {
      expect(
        sale(
          slots: const <Slot>[Slot(name: 'unitCost', value: null)],
        ).valueOf<double>('unitCost'),
        isNull,
      );
    });
  });

  group('doutes', () {
    final CommandProposal doubted = sale(
      doubts: const <Doubt>[
        Doubt(kind: DoubtKind.unknownProduct),
        Doubt(kind: DoubtKind.missingQuantity, slotName: 'items'),
      ],
    );

    test('isComplete dit si la proposition est routable', () {
      expect(sale().isComplete, isTrue);
      expect(doubted.isComplete, isFalse);
    });

    test('hasDoubt repond vrai des qu un doute de ce genre existe', () {
      expect(doubted.hasDoubt(DoubtKind.unknownProduct), isTrue);
      expect(doubted.hasDoubt(DoubtKind.archivedProduct), isFalse);
    });

    test('doubtOf rend le doute demande', () {
      expect(doubted.doubtOf(DoubtKind.missingQuantity)?.slotName, 'items');
      expect(doubted.doubtOf(DoubtKind.archivedProduct), isNull);
    });

    test('doubtOf rend le premier quand le genre se repete', () {
      final CommandProposal twice = sale(
        doubts: const <Doubt>[
          Doubt(kind: DoubtKind.missingProduct, slotName: 'items'),
          Doubt(kind: DoubtKind.missingProduct, slotName: 'unitCost'),
        ],
      );

      expect(twice.doubtOf(DoubtKind.missingProduct)?.slotName, 'items');
    });

    test('une proposition des regles a des doubts vides par defaut', () {
      const CommandProposal fromRules = CommandProposal.rules(
        intentId: 'query_stock',
        slots: <Slot>[product],
      );

      expect(fromRules.origin, ProposalOrigin.rules);
      expect(fromRules.isComplete, isTrue);
    });
  });

  group('descriptions', () {
    test('une proposition se lit sans vider ses slots', () {
      expect(
        sale(doubts: const <Doubt>[Doubt.missingProduct()]).toString(),
        'CommandProposal(record_sale, 2 slots, 1 doubts)',
      );
    });

    test('un doute nomme le slot quand il en a un', () {
      expect(
        const Doubt(
          kind: DoubtKind.missingQuantity,
          slotName: 'items',
        ).toString(),
        'Doubt(missingQuantity, items)',
      );
      expect(Doubt.missingProduct().toString(), 'Doubt(missingProduct)');
    });

    test('un slot se lit avec sa valeur', () {
      expect(qty.toString(), 'Slot(qty: 2.0)');
    });
  });

  group('VoiceConfig', () {
    test('les defauts sont les seuils documentes', () {
      const VoiceConfig config = VoiceConfig();

      expect(config.unusualQuantityThreshold, kDefaultUnusualQuantity);
      expect(config.shopQuantityCeiling, kDefaultShopQuantityCeiling);
      expect(config.priceToleranceRatio, kDefaultPriceTolerance);
      expect(config.fuzzyThreshold, kDefaultFuzzyThreshold);
      expect(config.ambiguityMargin, kDefaultAmbiguityMargin);
      expect(config.underSpecifiedNames, kUnderSpecifiedNames);
    });

    test('copyWith change un seul seuil et garde les autres', () {
      const VoiceConfig config = VoiceConfig();

      final VoiceConfig loosened = config.copyWith(fuzzyThreshold: 0.6);

      expect(loosened.fuzzyThreshold, 0.6);
      expect(
        loosened.unusualQuantityThreshold,
        config.unusualQuantityThreshold,
      );
      expect(loosened.ambiguityMargin, config.ambiguityMargin);
    });

    test('copyWith sans argument redonne la meme configuration', () {
      const VoiceConfig config = VoiceConfig();

      final VoiceConfig copy = config.copyWith();

      expect(copy.shopQuantityCeiling, config.shopQuantityCeiling);
      expect(copy.unusualQuantityThreshold, config.unusualQuantityThreshold);
      expect(copy.fuzzyThreshold, config.fuzzyThreshold);
      expect(copy.underSpecifiedNames, config.underSpecifiedNames);
    });
  });
}
