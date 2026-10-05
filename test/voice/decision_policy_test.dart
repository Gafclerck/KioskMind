import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';

/// The exhaustive decision table of the module.
///
/// Every doubt the parser or the validator can raise is paired here with every
/// risk class, and each pair says which of the five issues comes out. The table
/// is data, not a chain of conditions: adding a doubt to [DoubtKind] without
/// deciding what it means makes the totality test below fail, which is the point.
void main() {
  /// Every doubt, so the table cannot silently forget one.
  final Set<DoubtKind> allDoubts = <DoubtKind>{...DoubtKind.values};

  const List<IntentRisk> allRisks = <IntentRisk>[
    IntentRisk.read,
    IntentRisk.writeReversible,
    IntentRisk.writeSensitive,
  ];

  /// The whole table. One row per combination the policy is asked about.
  const List<(IntentRisk, List<DoubtKind>, DecisionOutcome)>
  table = <(IntentRisk, List<DoubtKind>, DecisionOutcome)>[
    // A clean proposal: the issue follows the risk, nothing else.
    (IntentRisk.read, <DoubtKind>[], DecisionOutcome.execute),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[],
      DecisionOutcome.executeWithUndo,
    ),
    (IntentRisk.writeSensitive, <DoubtKind>[], DecisionOutcome.askConfirmation),

    // A doubt about a value the merchant stated is confirmed, not asked
    // again: they already said it, they only have to agree.
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.amountMismatch],
      DecisionOutcome.askConfirmation,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.implausibleQuantity],
      DecisionOutcome.askConfirmation,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.amountMismatch, DoubtKind.implausibleQuantity],
      DecisionOutcome.askConfirmation,
    ),

    // A doubt about what was meant is a question: only the merchant can say.
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.missingProduct],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.unknownProduct],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.ambiguousProduct],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.missingQuantity],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.undeterminedQuantity],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.anaphora],
      DecisionOutcome.askClarification,
    ),

    // A doubt about meaning outranks one about scope: an utterance that
    // names no product is asked about even when it also asks for something
    // the module does not do. Asked first, it can still be refused then.
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.missingQuantity, DoubtKind.outOfScope],
      DecisionOutcome.askClarification,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[
        DoubtKind.anaphora,
        DoubtKind.undeterminedQuantity,
        DoubtKind.unknownProduct,
      ],
      DecisionOutcome.askClarification,
    ),

    // A doubt that means the command must not run at all is a refusal, and
    // nothing else in the proposal can make it run.
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.archivedProduct],
      DecisionOutcome.reject,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.destructiveRequest],
      DecisionOutcome.reject,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.noOrderUseCase],
      DecisionOutcome.reject,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.unboundedScope],
      DecisionOutcome.reject,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.outOfDomain],
      DecisionOutcome.reject,
    ),
    (
      IntentRisk.writeReversible,
      <DoubtKind>[DoubtKind.invalidQuantity],
      DecisionOutcome.reject,
    ),

    // Risk does not soften a refusal: a read of an archived product is
    // refused like a write.
    (
      IntentRisk.read,
      <DoubtKind>[DoubtKind.archivedProduct],
      DecisionOutcome.reject,
    ),
  ];

  String key(IntentRisk risk, List<DoubtKind> doubts) =>
      '${risk.code}/${doubts.map((DoubtKind d) => d.name).toList()..sort()}';

  DecisionPolicy policyFor(IntentRisk risk) =>
      DecisionPolicy(catalog: _catalogWith(risk));

  CommandProposal proposalFor(String intent, List<Doubt> doubts) =>
      CommandProposal(
        intentId: intent,
        slots: const <Slot>[],
        doubts: doubts,
        origin: ProposalOrigin.rules,
      );

  test('la table est totale: chaque doute y a une ligne', () {
    final Set<DoubtKind> covered = <DoubtKind>{
      for (final (IntentRisk _, List<DoubtKind> doubts, DecisionOutcome _)
          in table)
        ...doubts,
    };

    expect(
      covered.difference(allDoubts).isEmpty,
      isTrue,
      reason: 'doutes hors table: ${covered.difference(allDoubts)}',
    );
    expect(
      allDoubts.difference(covered),
      isEmpty,
      reason: 'doutes sans ligne: ${allDoubts.difference(covered)}',
    );
  });

  test('la table est coherente: une meme entree ne dit pas deux choses', () {
    final Map<String, DecisionOutcome> seen = <String, DecisionOutcome>{};

    for (final (IntentRisk risk, List<DoubtKind> doubts, DecisionOutcome out)
        in table) {
      final String entry = key(risk, doubts);
      expect(
        seen[entry] ?? out,
        out,
        reason: '$entry vaut ${seen[entry]} et $out',
      );
      seen[entry] = out;
    }
  });

  test('la table produit les cinq issues', () {
    final Set<DecisionOutcome> produced = <DecisionOutcome>{
      for (final (IntentRisk _, List<DoubtKind> _, DecisionOutcome out)
          in table)
        out,
    };

    expect(produced, <DecisionOutcome>{...DecisionOutcome.values});
  });

  test('chaque ligne de la table est ce que la policy renvoie', () {
    for (final (IntentRisk risk, List<DoubtKind> doubts, DecisionOutcome out)
        in table) {
      final Decision decision = policyFor(risk).decide(
        proposalFor(
          risk == IntentRisk.read ? 'query_stock' : 'record_sale',
          <Doubt>[for (final DoubtKind kind in doubts) Doubt(kind: kind)],
        ),
      );

      expect(decision.outcome, out, reason: key(risk, doubts));
    }
  });

  group('ce que la decision porte', () {
    test('un refus nomme le doute qui l a provoque', () {
      final Decision decision = policyFor(IntentRisk.writeReversible).decide(
        proposalFor('record_sale', const <Doubt>[
          Doubt(kind: DoubtKind.archivedProduct, slotName: 'items'),
        ]),
      );

      expect(decision.outcome, DecisionOutcome.reject);
      expect(decision.reason, DoubtKind.archivedProduct);
      expect(decision.executes, isFalse);
      expect(decision.isQuestion, isFalse);
      expect(decision.toString(), 'Decision(REJECT, archivedProduct)');
    });

    test('une execution ne nomme aucun doute', () {
      final Decision decision = policyFor(
        IntentRisk.read,
      ).decide(proposalFor('query_stock', const <Doubt>[]));

      expect(decision.outcome, DecisionOutcome.execute);
      expect(decision.reason, isNull);
      expect(decision.executes, isTrue);
      expect(decision.toString(), 'Decision(EXECUTE)');
    });

    test(
      'une question est une question, meme si elle est un doute de prix',
      () {
        final Decision decision = policyFor(IntentRisk.writeReversible).decide(
          proposalFor('record_restock', const <Doubt>[
            Doubt(kind: DoubtKind.amountMismatch, slotName: 'items'),
          ]),
        );

        expect(decision.isQuestion, isTrue);
        expect(DecisionOutcome.askConfirmation.runsNow, isFalse);
        expect(DecisionOutcome.askConfirmation.asksSomething, isTrue);
        expect(DecisionOutcome.executeWithUndo.runsNow, isTrue);
        expect(DecisionOutcome.askClarification.asksSomething, isTrue);
        expect(DecisionOutcome.reject.asksSomething, isFalse);
      },
    );
  });

  group('sans intent', () {
    test('une proposition sans commande est refusee', () {
      // Le parseur leve outOfDomain sur tout ce qui ne ressemble a aucune
      // commande, mais une proposition vide reste un refus, pas une question:
      // demander "de quoi voulez-vous parler" a quelqu un qui a dit la meteo
      // ne fait que faire perdre un tour.
      final Decision decision = policyFor(IntentRisk.read).decide(
        const CommandProposal(
          intentId: kNoIntent,
          slots: <Slot>[],
          doubts: <Doubt>[],
          origin: ProposalOrigin.rules,
        ),
      );

      expect(decision.outcome, DecisionOutcome.reject);
      expect(decision.reason, DoubtKind.outOfDomain);
    });
  });

  group('chaque doute seul', () {
    test('les six doubts qui refusent refusent, pour tout risque', () {
      const Set<DoubtKind> refusing = <DoubtKind>{
        DoubtKind.archivedProduct,
        DoubtKind.destructiveRequest,
        DoubtKind.invalidQuantity,
        DoubtKind.noOrderUseCase,
        DoubtKind.outOfDomain,
        DoubtKind.unboundedScope,
      };

      for (final IntentRisk risk in allRisks) {
        for (final DoubtKind kind in allDoubts) {
          final Decision decision = policyFor(risk).decide(
            proposalFor(
              risk == IntentRisk.read ? 'query_stock' : 'record_sale',
              <Doubt>[Doubt(kind: kind)],
            ),
          );

          expect(
            decision.outcome == DecisionOutcome.reject,
            refusing.contains(kind),
            reason: '${risk.code} + ${kind.name} -> ${decision.outcome.code}',
          );
        }
      }
    });

    test('aucun doute ne rend un ASK_CONFIRMATION quand il ne le doit pas', () {
      // Une confirmation ne se justifie que par un doute sur une valeur dite, ou
      // par un risque sensible. Tout le reste est une question.
      for (final DoubtKind kind in allDoubts) {
        final Decision decision = policyFor(
          IntentRisk.read,
        ).decide(proposalFor('query_stock', <Doubt>[Doubt(kind: kind)]));

        expect(
          decision.outcome,
          isNot(DecisionOutcome.askConfirmation),
          reason: 'lecture + ${kind.name}',
        );
      }
    });

    test('une écriture sensible avec kConfirmedSlot=true produit EXECUTE au lieu de redemander confirmation', () {
      final DecisionPolicy policy = policyFor(IntentRisk.writeSensitive);
      final CommandProposal unconfirmed = CommandProposal(
        intentId: 'record_sale',
        slots: const <Slot>[],
        doubts: const <Doubt>[],
        origin: ProposalOrigin.rules,
      );
      expect(policy.decide(unconfirmed).outcome, DecisionOutcome.askConfirmation);

      final CommandProposal confirmed = CommandProposal(
        intentId: 'record_sale',
        slots: const <Slot>[Slot(name: kConfirmedSlot, value: true)],
        doubts: const <Doubt>[],
        origin: ProposalOrigin.rules,
      );
      expect(policy.decide(confirmed).outcome, DecisionOutcome.execute);
    });
  });
}

/// A catalog whose only intent carries [risk], so the policy can be asked about
/// one risk at a time without a fixture.
IntentCatalog _catalogWith(IntentRisk risk) {
  return IntentCatalog(
    currency: 'XOF',
    intents: <IntentDefinition>[
      IntentDefinition(
        id: 'record_sale',
        handler: 'record_sale',
        risk: risk,
        description: 'vente',
        triggers: const <String>['vendu'],
        examples: const <String>[],
        slots: const <SlotDefinition>[],
      ),
      IntentDefinition(
        id: 'record_restock',
        handler: 'record_restock',
        risk: risk,
        description: 'approvisionnement',
        triggers: const <String>['recu'],
        examples: const <String>[],
        slots: const <SlotDefinition>[],
      ),
      IntentDefinition(
        id: 'query_stock',
        handler: 'query_stock',
        risk: IntentRisk.read,
        description: 'stock',
        triggers: const <String>['stock'],
        examples: const <String>[],
        slots: const <SlotDefinition>[],
      ),
    ],
  );
}
