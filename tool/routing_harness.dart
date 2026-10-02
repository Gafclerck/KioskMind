import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/product_name_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/voice_clock.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_application.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_reading.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/handle_utterance.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';

import 'routing_cases.dart';

/// The whole pipeline, wired the way the composition root wires it, and the
/// evidence it leaves: one issue, and the calls that reached a handler.
///
/// The routing metric is built on this and nothing else, so the number
/// `voice_eval --level routing` prints is the number `routing_test.dart`
/// asserts. A second wiring would let the metric drift from the code.
///
/// The frozen answers stand in for the follow-up utterance the merchant would
/// actually speak. In the app that word is read by [AnswerReading] and completed by
/// [AnswerApplication]. Here the frozen case gives the answer already resolved, so the
/// harness hands it to [HandleUtterance.applyAnswer] instead. Both go through the same
/// use case and the same services, which is why this file holds no rule of its own: a
/// table that existed only to measure the pipeline would drift from the pipeline it
/// measures.
final class RoutingHarness {
  RoutingHarness({this.config = const VoiceConfig()}) {
    normalizer = TextNormalizer(fillers: config.fillers);
    intents = parseIntentCatalog(File(intentCatalogAsset).readAsStringSync());
    products = parseCatalogFixture(
      File('voice/golden/catalog_fixture.json').readAsStringSync(),
    );
    resolver = ProductResolver(
      products: products,
      config: config,
      normalizer: normalizer,
    );
    parser = RuleBasedParser(
      normalizer: normalizer,
      detector: IntentDetector(catalog: intents, normalizer: normalizer),
      items: ItemListExtractor(
        resolver: resolver,
        lines: LineExtractor(
          numbers: const FrenchNumberParser(),
          config: config,
        ),
      ),
      config: config,
    );
    journal = InMemoryCallJournal();
    catalog = InMemoryProductCatalog(products);
    clock = _FixedClock(DateTime(2026, 3, 14, 8));
    dialog = DialogManager(config: config, clock: clock);
    handlers = buildMockVoiceHandlers(catalog: catalog, journal: journal);
    policy = DecisionPolicy(catalog: intents);
    validator = CommandValidator(config: config);
    answers = AnswerApplication(
      intents: intents,
      resolver: ProductNameResolver(resolver: resolver, normalizer: normalizer),
    );
    undoer = UndoLastCommand(
      handlers: handlers,
      dialog: dialog,
      clock: clock,
      ids: _CountingIds(),
    );
    executor = ExecuteCommand(
      handlers: handlers,
      dialog: dialog,
      clock: clock,
      ids: _CountingIds(),
      undo: undoer,
    );
    turn = HandleUtterance(
      parser: parser,
      validator: validator,
      policy: policy,
      executor: executor,
      dialog: dialog,
      answers: answers,
      reading: AnswerReading(
        normalizer: normalizer,
        numbers: const FrenchNumberParser(),
        products: ProductNameResolver(
          resolver: resolver,
          normalizer: normalizer,
        ),
      ),
    );
  }

  final VoiceConfig config;

  late final TextNormalizer normalizer;
  late final IntentCatalog intents;
  late final List<ProductSnapshot> products;
  late final ProductResolver resolver;
  late final RuleBasedParser parser;
  late final InMemoryCallJournal journal;
  late final InMemoryProductCatalog catalog;
  late final VoiceClock clock;
  late final DialogManager dialog;
  late final VoiceHandlers handlers;
  late final DecisionPolicy policy;
  late final CommandValidator validator;

  /// The domain service that completes a line from an answer, shared with the app.
  late final AnswerApplication answers;
  late final UndoLastCommand undoer;
  late final ExecuteCommand executor;

  /// The turn itself, shared with the app: the harness calls it and reads the
  /// result, never the policy or the executor.
  late final HandleUtterance turn;

  /// The id of the sale [kPrimingSale] recorded, set only when a case asks for a
  /// session that already recorded one.
  String? primedSaleId;

  /// The issue, the doubts, and the handler calls of one utterance.
  Future<Route> run(
    String utterance, {
    List<AnsweredSlot> answers = const <AnsweredSlot>[],
    bool withSession = false,
  }) async {
    journal.clear();
    dialog.reset();
    if (withSession) {
      await _recordPrimingSale();
    }
    journal.clear();

    // One utterance is one turn. The answers of a frozen case are the follow-up
    // turns the merchant would speak, so they are fed back turn by turn: naming a
    // product on an utterance that named none leaves the quantity missing, the
    // session asks twice, and the loop stops as soon as no answer is left, which
    // is how a case that expects a question ends with no call.
    VoiceTurn current = await turn.run(utterance);
    final String firstOutcome = current.decision.outcome.code;
    var pending = answers;
    while (current.decision.isQuestion && pending.isNotEmpty) {
      final AnsweredSlot answer = pending.first;
      pending = pending.sublist(1);
      current = await turn.applyAnswer(
        asked: current.decision.reason ?? DoubtKind.outOfDomain,
        value: answer.value,
      );
    }
    return Route(
      decision: current.decision,
      firstOutcome: firstOutcome,
      doubts: current.proposal.doubts,
      calls: journal.calls,
    );
  }

  /// Records the sale a cancellation will act on.
  ///
  /// `annule` cancels the last sale of the session, so a session that recorded
  /// none has nothing to undo. A frozen case states `saleId: "$lastSaleId"`
  /// without saying which sale that is: the harness records [kPrimingSale]
  /// first, the same utterance for every such case, and the judge compares the id
  /// the handler received with [primedSaleId].
  Future<void> _recordPrimingSale() async {
    await run(kPrimingSale);
    primedSaleId = dialog.undoSaleId;
  }
}

/// What one utterance produced.
final class Route {
  Route({
    required this.decision,
    required this.firstOutcome,
    required this.doubts,
    required this.calls,
  });

  /// The issue the pipeline settled on, answers included.
  final Decision decision;

  /// The issue the first turn produced, before any answer was applied. A case
  /// expecting a clarification is judged on this one, since that is the turn the
  /// merchant actually sees.
  final String firstOutcome;

  final List<Doubt> doubts;
  final List<HandlerCall> calls;

  /// The issue, as the vocabulary word the frozen set uses.
  String get outcome => decision.outcome.code;

  /// The single call the metric compares, or null when none was made.
  HandlerCall? get call => calls.isEmpty ? null : calls.first;
}

/// The sale a cancellation undoes when the frozen case does not say which one.
///
/// `annule` acts on the last sale of the session, so a session that recorded none
/// has nothing to undo. The same utterance is recorded for every such case, and
/// the judge compares the id the handler received with [RoutingHarness.primedSaleId].
const String kPrimingSale = 'vendu un sucre';

/// A clock that never moves, so a routing run measures routing.
final class _FixedClock implements VoiceClock {
  _FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime now() => _instant;
}

/// Command identifiers that only have to be different from each other.
final class _CountingIds implements CommandIdFactory {
  int _count = 0;

  @override
  String next() => 'cmd-${++_count}';
}
