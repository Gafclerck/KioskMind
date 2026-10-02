import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart'
    show parseCatalogFixture;
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/product_name_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_application.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_reading.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/handle_utterance.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';

import 'fake_clock.dart';
import 'rule_parser_harness.dart';

/// A session, spoken word by word.
///
/// The evidence is the journal: what the merchant said ends in a call to exactly
/// one handler, with exactly the arguments he gave. A dialogue is therefore read as
/// a sequence of utterances, the way the microphone delivers them, and not as a case
/// holding its answers: "vendu deux" is heard, then the session asks, then "sucre" is
/// heard, and only then does a sale reach the handler.
void main() {
  group('une commande complete', () {
    test('une vente nette appelle le handler de vente', () async {
      final _Session session = _Session();

      final VoiceTurn turn = await session.speak('vendu deux sucres');

      expect(turn.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(turn.executed, isTrue);
      expect(session.calls, hasLength(1));
      expect(session.calls.single.intentId, 'record_sale');
      expect(session.calls.single.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 2.0},
        ],
      });
    });

    test('une lecture appelle le handler de lecture', () async {
      final _Session session = _Session();

      final VoiceTurn turn = await session.speak('combien de sucre il reste');

      expect(turn.decision.outcome, DecisionOutcome.execute);
      expect(session.calls.single.intentId, 'query_stock');
    });
  });

  group('une reponse est une nouvelle utterance', () {
    test(
      'nommer le produit complete la ligne et enregistre la vente',
      () async {
        final _Session session = _Session();

        final VoiceTurn asked = await session.speak('vendu deux');
        expect(asked.decision.outcome, DecisionOutcome.askClarification);
        expect(session.calls, isEmpty);

        final VoiceTurn answered = await session.speak('sucre');

        expect(answered.decision.outcome, DecisionOutcome.executeWithUndo);
        expect(session.calls.single.handlerArgs, <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'productId': 'p_sucre', 'qty': 2.0},
          ],
        });
      },
    );

    test('la reponse garde ce que le commerçant avait deja dit', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      // Le deux a ete dit avant la question: nommer le produit ne l efface pas.
      final VoiceTurn answered = await session.speak('sucre');

      expect(answered.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(session.calls.single.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 2.0},
        ],
      });
    });

    test('une quantite jamais dite fait une deuxieme question', () async {
      final _Session session = _Session();

      final VoiceTurn first = await session.speak('vendu');
      expect(first.decision.reason, DoubtKind.missingProduct);

      // Nommer le produit ne vaut pas une quantite: la question suit au lieu
      // d enregistrer une vente d une seule unite.
      final VoiceTurn second = await session.speak('sucre');
      expect(second.decision.reason, DoubtKind.missingQuantity);
      expect(session.calls, isEmpty);

      final VoiceTurn third = await session.speak('cinq');

      expect(third.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(session.calls.single.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 5.0},
        ],
      });
    });

    test(
      'une quantite demandee se repond sans repasser par le produit',
      () async {
        final _Session session = _Session();

        final VoiceTurn asked = await session.speak('vendu du sucre');
        expect(asked.decision.reason, DoubtKind.missingQuantity);

        final VoiceTurn answered = await session.speak('cinq');

        expect(answered.decision.outcome, DecisionOutcome.executeWithUndo);
        expect(session.calls.single.handlerArgs, <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'productId': 'p_sucre', 'qty': 5.0},
          ],
        });
      },
    );

    test('une reponse qui ne dit rien laisse la question ouverte', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      final VoiceTurn turn = await session.speak('euh');

      expect(turn.decision.outcome, DecisionOutcome.askClarification);
      expect(session.calls, isEmpty);
      expect(session.dialog.pending, isNotNull);
    });

    test('un produit archive ne repond pas a la question', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      final VoiceTurn turn = await session.speak('vieux lait');

      expect(turn.decision.outcome, DecisionOutcome.askClarification);
      expect(session.calls, isEmpty);
    });

    test('dire oui confirme une vente doubtée', () async {
      final _Session session = _Session();

      // Cinquante sucres sortent de l'ordinaire pour ce commerçant.
      final VoiceTurn asked = await session.speak('vendu cinquante sucres');
      expect(asked.decision.outcome, DecisionOutcome.askConfirmation);

      final VoiceTurn answered = await session.speak('oui');

      expect(answered.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(session.calls.single.intentId, 'record_sale');
    });

    test('dire non ne confirme rien et ne vend pas', () async {
      final _Session session = _Session();

      await session.speak('vendu cinquante sucres');
      final VoiceTurn answered = await session.speak('non');

      expect(answered.executed, isFalse);
      expect(session.calls, isEmpty);
      expect(session.dialog.pending, isNotNull);
    });
  });

  group('les portes de sortie', () {
    test('trois questions de suite ouvrent les ecrans manuels', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      await session.speak('euh');
      await session.speak('euh');

      expect(session.dialog.awaitsManualEntry, isTrue);
      expect(session.calls, isEmpty);
    });

    test('apres les ecrans manuels une parole ne relance rien', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      await session.speak('euh');
      await session.speak('euh');
      final VoiceTurn turn = await session.speak('sucre');

      expect(turn.executed, isFalse);
      expect(session.calls, isEmpty);
    });

    test('une session qui expire oublie la question', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      session.clock.elapse(const Duration(seconds: 31));
      final VoiceTurn turn = await session.speak('sucre');

      // Le mot seul ne commande rien: il est lu comme une commande et refuse.
      expect(turn.decision.outcome, DecisionOutcome.reject);
      expect(session.calls, isEmpty);
    });
  });

  group('une reponse deja resolue', () {
    test('complete la question en cours avec la valeur fournie', () async {
      final _Session session = _Session();

      await session.speak('vendu deux');
      final VoiceTurn turn = await session.turn.applyAnswer(
        asked: DoubtKind.missingProduct,
        value: 'sucre',
      );

      expect(turn.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(session.calls.single.handlerArgs, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 2.0},
        ],
      });
    });

    test(
      'echoue bruyamment quand aucune question n attend de reponse',
      () async {
        final _Session session = _Session();

        await expectLater(
          session.turn.applyAnswer(
            asked: DoubtKind.missingProduct,
            value: 'sucre',
          ),
          throwsStateError,
        );
      },
    );
  });
}

/// A session over the shipped catalog, the mock handlers and a clock the test
/// moves by hand.
///
/// The wiring is the one the composition root builds, minus the providers: the same
/// parser, the same resolver, the same dialog, the same use case.
final class _Session {
  _Session() {
    harness = RuleParserHarness();
    clock = FakeClock(DateTime(2026, 3, 14, 8));
    journal = InMemoryCallJournal();
    catalog = InMemoryProductCatalog(
      parseCatalogFixture(File(catalogFixtureAsset).readAsStringSync()),
    );
    dialog = DialogManager(config: harness.config, clock: clock);
    final VoiceHandlers handlers = buildMockVoiceHandlers(
      catalog: catalog,
      journal: journal,
    );
    turn = HandleUtterance(
      parser: harness.parser,
      validator: CommandValidator(config: harness.config),
      policy: DecisionPolicy(catalog: harness.intents),
      executor: ExecuteCommand(
        handlers: handlers,
        dialog: dialog,
        clock: clock,
        ids: _SequentialIds(),
        undo: UndoLastCommand(
          handlers: handlers,
          dialog: dialog,
          clock: clock,
          ids: _SequentialIds(prefix: 'undo-'),
        ),
      ),
      dialog: dialog,
      answers: AnswerApplication(
        intents: harness.intents,
        resolver: ProductNameResolver(
          resolver: harness.resolver,
          normalizer: harness.normalizer,
        ),
      ),
      reading: AnswerReading(
        normalizer: harness.normalizer,
        numbers: const FrenchNumberParser(),
        products: ProductNameResolver(
          resolver: harness.resolver,
          normalizer: harness.normalizer,
        ),
      ),
    );
  }

  late final RuleParserHarness harness;
  late final FakeClock clock;
  late final InMemoryCallJournal journal;
  late final InMemoryProductCatalog catalog;
  late final DialogManager dialog;
  late final HandleUtterance turn;

  /// What the handlers were called with, which is the only evidence that matters.
  List<HandlerCall> get calls => journal.calls;

  Future<VoiceTurn> speak(String utterance) => turn.run(utterance);
}

final class _SequentialIds implements CommandIdFactory {
  _SequentialIds({this.prefix = 'cmd-'});

  /// Keeps the two paths apart: a cancellation is a command of its own, and its
  /// identifier must not be read as the identifier of the sale it targets.
  final String prefix;

  int _next = 1;

  @override
  String next() => '$prefix${_next++}';
}
