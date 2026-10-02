import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';

import 'fake_clock.dart';

/// The session state machine, on a clock the test moves by hand.
///
/// The invariants pinned here are the ones a widget test cannot: a wait always
/// expires, an expired wait never comes back, a command never draws more than the
/// configured number of questions, and a write can be undone only inside its
/// window.
void main() {
  final FakeClock clock = FakeClock(DateTime(2026, 3, 14, 8));

  DialogManager managerWith({VoiceConfig config = const VoiceConfig()}) =>
      DialogManager(config: config, clock: clock);

  setUp(() => clock.set(DateTime(2026, 3, 14, 8)));

  group('au repos', () {
    test('une session neuve n attend rien', () {
      final DialogManager manager = managerWith();

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.pending, isNull);
      expect(manager.awaitsManualEntry, isFalse);
      expect(manager.undoSaleId, isNull);
    });

    test('une session sans activite expire', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.execute));

      clock.elapse(const Duration(seconds: 29));
      expect(manager.state, VoiceDialogState.idle, reason: 'pas encore');

      clock.elapse(const Duration(seconds: 2));
      expect(manager.state, VoiceDialogState.expired);
    });

    test('une session qui expire oublie le tour en cours', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      clock.elapse(const Duration(seconds: 31));

      expect(manager.state, VoiceDialogState.expired);
      expect(manager.pending, isNull);
    });
  });

  group('ce qui est en attente de reponse', () {
    test('l utterance posee est celle que la reponse doit completer', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingQuantity),
        proposal: _withLines(),
      );

      expect(manager.awaiting, isNotNull);
      expect(manager.awaiting!.intentId, 'record_sale');
    });

    test('rien n est en attente quand aucune question n est posee', () {
      expect(managerWith().awaiting, isNull);
    });

    test('une question qui expire ne laisse plus d utterance a completer', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      clock.elapse(const Duration(seconds: 11));

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.awaiting, isNull);
    });

    test('offrir les ecrans manuels abandonne l utterance posee', () {
      final DialogManager manager = managerWith();
      for (int turn = 0; turn < 3; turn += 1) {
        manager.ask(
          _clarification(DoubtKind.missingProduct),
          proposal: _withLines(),
        );
      }

      expect(manager.awaitsManualEntry, isTrue);
      expect(manager.awaiting, isNull);
    });
  });

  group('ce qui ne demande rien', () {
    test('une lecture rend la session disponible', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      manager.decide(_decision(DecisionOutcome.execute));

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.pending, isNull);
    });

    test('un refus rend la session disponible', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      manager.decide(_decision(DecisionOutcome.reject));

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.pending, isNull);
    });

    test('une confirmation remplace une clarification en cours', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingQuantity),
        proposal: _withLines(),
      );

      manager.ask(
        _confirmation(DoubtKind.implausibleQuantity),
        proposal: _withLines(),
      );

      expect(manager.state, VoiceDialogState.waitingForConfirmation);
      expect(manager.turns, 1, reason: 'une confirmation n est pas un tour');
    });
  });

  group('ce qui demande', () {
    test('une clarification dit sur quoi elle attend', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.ambiguousProduct),
        proposal: _withLines(),
      );

      expect(manager.state, VoiceDialogState.waitingForAnswer);
      expect(manager.pending!.slot, ClarificationSlot.itemProductName);
      expect(manager.pending!.reason, DoubtKind.ambiguousProduct);
      expect(manager.turns, 1);
    });

    test('une lecture n attend pas une ligne', () {
      // Une question de stock ne porte pas de ligne, donc le produit se nomme
      // ailleurs que dans les articles.
      final DialogManager manager = managerWith();
      manager.ask(
        _decision(DecisionOutcome.askClarification, DoubtKind.missingProduct),
        proposal: _withoutLines(),
      );

      expect(manager.pending!.slot, ClarificationSlot.productName);
    });

    test('une quantite manquante attend la quantite', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingQuantity),
        proposal: _withLines(),
      );

      expect(manager.pending!.slot, ClarificationSlot.itemQty);
    });

    test('une confirmation attend un oui ou un non', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _confirmation(DoubtKind.implausibleQuantity),
        proposal: _withLines(),
      );

      expect(manager.state, VoiceDialogState.waitingForConfirmation);
      expect(manager.pending!.slot, ClarificationSlot.confirmed);
      expect(manager.turns, 0);
    });
  });

  group('limite de tours', () {
    test('deux clarifications suffisent, la troisieme non', () {
      final DialogManager manager = managerWith();

      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      expect(manager.state, VoiceDialogState.waitingForAnswer);
      manager.ask(
        _clarification(DoubtKind.missingQuantity),
        proposal: _withLines(),
      );
      expect(manager.state, VoiceDialogState.waitingForAnswer);

      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.awaitsManualEntry, isTrue);
      expect(manager.pending, isNull);
    });

    test('la limite est une configuration', () {
      final DialogManager manager = managerWith(
        config: const VoiceConfig().copyWith(maxClarificationTurns: 5),
      );

      for (int index = 0; index < 5; index++) {
        manager.ask(
          _clarification(DoubtKind.missingProduct),
          proposal: _withLines(),
        );
      }

      expect(manager.state, VoiceDialogState.waitingForAnswer);
      expect(manager.turns, 5);
    });

    test('apres la sortie manuelle, la session ne repart pas', () {
      // Le marchand passe aux ecrans: une phrase entendue a cote ne doit pas
      // ressusciter un dialogue deja abandonne.
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      manager.decide(_decision(DecisionOutcome.executeWithUndo));

      expect(manager.awaitsManualEntry, isTrue);
      expect(manager.pending, isNull);
      expect(manager.undoSaleId, isNull);
    });

    test('reinitialiser rouvre une session', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      manager.reset();

      expect(manager.awaitsManualEntry, isFalse);
      expect(manager.turns, 0);
      expect(manager.state, VoiceDialogState.idle);
    });
  });

  group('expiration d une question', () {
    test('une question sans reponse propose la saisie manuelle', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      clock.elapse(const Duration(seconds: 9));
      expect(manager.state, VoiceDialogState.waitingForAnswer);

      clock.elapse(const Duration(seconds: 2));

      expect(manager.state, VoiceDialogState.idle);
      expect(manager.awaitsManualEntry, isTrue);
      expect(manager.pending, isNull);
    });

    test('une reponse avant l echeance redonne la main', () {
      final DialogManager manager = managerWith();
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );
      clock.elapse(const Duration(seconds: 9));
      manager.decide(_decision(DecisionOutcome.execute));

      // Au-dela du delai de question mais avant l expiration de session: la
      // question a ete repondue, donc rien n est propose.
      clock.elapse(const Duration(seconds: 20));

      expect(manager.awaitsManualEntry, isFalse);
      expect(manager.state, VoiceDialogState.idle);
    });

    test('le delai est une configuration', () {
      final DialogManager manager = managerWith(
        config: const VoiceConfig().copyWith(
          questionTimeout: Duration(seconds: 2),
        ),
      );
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      clock.elapse(const Duration(seconds: 3));

      expect(manager.awaitsManualEntry, isTrue);
    });
  });

  group('fenetre d annulation', () {
    test('une ecriture ouvre une fenetre d annulation', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');

      expect(manager.undoSaleId, 'sale-1');
      expect(manager.remainingUndo, const Duration(seconds: 10));
    });

    test('une lecture n ouvre aucune fenetre', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.execute));

      expect(manager.undoSaleId, isNull);
      expect(manager.remainingUndo, Duration.zero);
    });

    test('la fenetre se ferme', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');

      clock.elapse(const Duration(seconds: 11));

      expect(manager.undoSaleId, isNull);
      expect(manager.remainingUndo, Duration.zero);
    });

    test('une ecriture renouvelle la fenetre', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');
      clock.elapse(const Duration(seconds: 5));
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-2');

      expect(manager.remainingUndo, const Duration(seconds: 10));
      expect(manager.undoSaleId, 'sale-2');
    });

    test('une question referme la fenetre', () {
      // Tant qu une question est en cours, un "annule" ne doit pas viser la vente
      // d'il y a dix secondes: le dialogue a la priorite.
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');
      manager.ask(
        _clarification(DoubtKind.missingProduct),
        proposal: _withLines(),
      );

      expect(manager.undoSaleId, isNull);
    });

    test('une vente de plus d une fenetre ne se rappelle pas', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');
      clock.elapse(const Duration(seconds: 11));
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-2');

      expect(manager.undoSaleId, 'sale-2');
    });

    test('annuler consomme la fenetre', () {
      final DialogManager manager = managerWith();
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');

      expect(manager.takeUndoable(), 'sale-1');
      expect(manager.undoSaleId, isNull);
    });

    test('rien a annuler ne rend aucun identifiant', () {
      expect(managerWith().takeUndoable(), isNull);
    });

    test('la fenetre est une configuration', () {
      final DialogManager manager = managerWith(
        config: const VoiceConfig().copyWith(undoWindow: Duration(seconds: 30)),
      );
      manager.decide(_decision(DecisionOutcome.executeWithUndo));
      manager.registerUndo('sale-1');

      expect(manager.remainingUndo, const Duration(seconds: 30));
    });
  });

  test('l activite prolonge la session', () {
    final DialogManager manager = managerWith();
    clock.elapse(const Duration(seconds: 20));
    manager.decide(_decision(DecisionOutcome.execute));
    clock.elapse(const Duration(seconds: 20));

    expect(manager.state, VoiceDialogState.idle);
  });
}

Decision _decision(DecisionOutcome outcome, [DoubtKind? reason]) =>
    Decision(outcome, reason: reason);

Decision _clarification(DoubtKind reason) =>
    _decision(DecisionOutcome.askClarification, reason);

Decision _confirmation(DoubtKind reason) =>
    _decision(DecisionOutcome.askConfirmation, reason);

/// A sale line, so a question about a product addresses the first one.
CommandProposal _withLines() => CommandProposal.rules(
  intentId: 'record_sale',
  slots: const <Slot>[Slot(name: kItemsSlot, value: <ItemMention>[])],
);

/// A stock question, which carries no line at all.
CommandProposal _withoutLines() =>
    CommandProposal.rules(intentId: 'query_stock', slots: const <Slot>[]);
