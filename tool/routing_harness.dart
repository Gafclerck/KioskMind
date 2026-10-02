import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/voice_clock.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';

import 'routing_cases.dart';

/// The whole pipeline, wired the way the composition root wires it, and the
/// evidence it leaves: one issue, and the calls that reached a handler.
///
/// The routing metric is built on this and nothing else, so the number
/// `voice_eval --level routing` prints is the number `routing_test.dart`
/// asserts. A second wiring would let the metric drift from the code.
///
/// [resolveAnswers] stands in for the follow-up utterance the merchant would
/// actually speak. In the app that word goes back through the parser and the
/// resolver, and the proposal it produces no longer carries the doubt that was
/// asked about. Here the frozen case gives the answer already resolved, so the
/// harness applies it to the proposal and drops the doubts it settles. The
/// application itself is the same table in both paths: a spoken product name goes
/// through [ProductResolver], and only the module that owns the catalog can do
/// it.
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
    executor = ExecuteCommand(
      handlers: handlers,
      dialog: dialog,
      clock: clock,
      ids: _CountingIds(),
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
  late final ExecuteCommand executor;

  /// The id of the sale [kPrimingSale] recorded, set only when a case asks for a
  /// session that already recorded one.
  String? primedSaleId;

  /// The proposal the last run started from, before the validator and the answers.
  /// Kept for the report; the metric does not read it.
  late CommandProposal lastProposal;

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

    CommandProposal proposal = parser.parse(utterance);
    lastProposal = proposal;
    proposal = _withValidatorDoubts(proposal);

    Decision decision = policy.decide(proposal);
    final Decision first = decision;
    // A question is answered, then judged again: naming a product on an utterance
    // that named none leaves the quantity missing, so the session asks twice and
    // the frozen set gives two answers. The loop stops as soon as no answer is
    // left, which is how a case that expects a question ends with no call.
    var remaining = answers;
    while (decision.isQuestion && remaining.isNotEmpty) {
      dialog.ask(
        decision,
        hasItems: proposal.valueOf<List<ItemMention>>(kItemsSlot) != null,
      );
      final AnsweredSlot answer = remaining.first;
      remaining = remaining.sublist(1);
      proposal = applyAnswers(
        proposal,
        answer,
        decision: decision,
        intents: intents,
        resolver: resolver,
        normalizer: normalizer,
      );
      decision = policy.decide(proposal);
    }
    if (decision.executes) {
      dialog.decide(decision);
      await executor.run(decision: decision, proposal: proposal);
    } else if (!decision.isQuestion) {
      dialog.decide(decision);
    }
    return Route(
      decision: decision,
      firstOutcome: first.outcome.code,
      doubts: proposal.doubts,
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

  /// Adds what the validator found to what the parser found.
  ///
  /// The two are kept apart so a test can state which raised a doubt, and the
  /// proposal the policy sees carries both, as it will in the app.
  CommandProposal _withValidatorDoubts(CommandProposal proposal) {
    final List<Doubt> doubts = <Doubt>[...proposal.doubts];
    for (final Doubt doubt in validator.validate(proposal)) {
      if (!doubts.contains(doubt)) {
        doubts.add(doubt);
      }
    }
    if (doubts.length == proposal.doubts.length) {
      return proposal;
    }
    return CommandProposal(
      intentId: proposal.intentId,
      slots: proposal.slots,
      doubts: doubts,
      origin: proposal.origin,
    );
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

/// Applies one answer of the frozen set to [proposal].
///
/// The address a case gives an answer (`productName` or `items[0].productName`) is
/// read as the doubt it answers rather than as a path into the proposal: the same
/// doubt is asked of a stock question and of a sale, and the frozen set writes the
/// two addresses for it. Taking the doubt as the address lets one rule serve both,
/// instead of a special case per address.
///
/// An answer the proposal cannot receive settles nothing: the doubt stays and the
/// case fails, rather than executing on a slot that was never filled.
CommandProposal applyAnswers(
  CommandProposal proposal,
  AnsweredSlot answer, {
  required Decision decision,
  required IntentCatalog intents,
  required ProductResolver resolver,
  required TextNormalizer normalizer,
}) {
  final DoubtKind asked = decision.reason ?? DoubtKind.outOfDomain;
  if (decision.outcome == DecisionOutcome.askConfirmation) {
    return _settle(proposal, const <DoubtKind>{
      DoubtKind.amountMismatch,
      DoubtKind.implausibleQuantity,
    });
  }
  final IntentDefinition? definition = intents.byId(proposal.intentId);
  if (definition == null) {
    return proposal;
  }
  if (_isProductDoubt(asked)) {
    final ProductSnapshot? product = _resolve(
      answer.value,
      resolver,
      normalizer,
    );
    if (product == null) {
      return proposal;
    }
    return _settle(
      _withProduct(proposal, product, intent: definition, asked: asked),
      <DoubtKind>{asked},
    );
  }
  if (_isQuantityDoubt(asked)) {
    final List<ItemMention>? lines = proposal.valueOf<List<ItemMention>>(
      kItemsSlot,
    );
    final Object? value = answer.value;
    if (value is! num) {
      return proposal;
    }
    final PartialLine? said = _partialLineOf(proposal, asked);
    final ProductSnapshot? product = said?.product ?? lines?.first.product;
    if (product == null) {
      return proposal;
    }
    return _settle(
      _withSlot(proposal, kItemsSlot, <ItemMention>[
        ItemMention(
          product: product,
          qty: value.toDouble(),
          spokenAmount: lines?.first.spokenAmount,
        ),
        ...lines?.skip(1) ?? const <ItemMention>[],
      ]),
      <DoubtKind>{asked},
    );
  }
  return proposal;
}

/// What the merchant had already said about the line the doubt is about.
PartialLine? _partialLineOf(CommandProposal proposal, DoubtKind asked) {
  for (final Doubt doubt in proposal.doubts) {
    if (doubt.kind == asked) {
      return doubt.partial;
    }
  }
  return null;
}

bool _isProductDoubt(DoubtKind doubt) =>
    doubt == DoubtKind.ambiguousProduct ||
    doubt == DoubtKind.unknownProduct ||
    doubt == DoubtKind.missingProduct;

bool _isQuantityDoubt(DoubtKind doubt) =>
    doubt == DoubtKind.missingQuantity ||
    doubt == DoubtKind.undeterminedQuantity;

/// Sets the product the answer named, on the place the intent asks for.
///
/// An utterance that named no product has no line at all, and naming one is what
/// the merchant is being asked for: the line is created with one unit, the same
/// reading the parser gives a bare product name inside an utterance. Which of the
/// two shapes applies is the intent's own statement, read from the catalog rather
/// than from a list written here.
CommandProposal _withProduct(
  CommandProposal proposal,
  ProductSnapshot product, {
  required IntentDefinition intent,
  required DoubtKind asked,
}) {
  final PartialLine? said = _partialLineOf(proposal, asked);
  final bool lineBased = intent.slots.any(
    (SlotDefinition slot) => slot.isItemList,
  );
  if (!lineBased) {
    return _withSlot(proposal, 'productId', product.id);
  }
  final List<ItemMention>? lines = proposal.valueOf<List<ItemMention>>(
    kItemsSlot,
  );
  return _withSlot(proposal, kItemsSlot, <ItemMention>[
    ItemMention(
      product: product,
      qty: said?.qty ?? lines?.first.qty ?? 1,
      spokenAmount: lines?.first.spokenAmount,
    ),
    ...lines?.skip(1) ?? const <ItemMention>[],
  ]);
}

/// Removes the doubts an answer answered, leaving every other doubt in place: a
/// refusal recorded by the doubt the question asked about stays recorded, so naming
/// the product does not turn an archived product back on.
CommandProposal _settle(CommandProposal proposal, Set<DoubtKind> settled) {
  final List<Doubt> remaining = <Doubt>[
    for (final Doubt doubt in proposal.doubts)
      if (!settled.contains(doubt.kind)) doubt,
  ];
  if (remaining.length == proposal.doubts.length) {
    return proposal;
  }
  return CommandProposal(
    intentId: proposal.intentId,
    slots: proposal.slots,
    doubts: remaining,
    origin: proposal.origin,
  );
}

/// Sets a slot, adding it when the utterance had none.
CommandProposal _withSlot(
  CommandProposal proposal,
  String name,
  Object? value,
) {
  final List<Slot> slots = <Slot>[
    for (final Slot slot in proposal.slots)
      if (slot.name == name) Slot(name: name, value: value) else slot,
  ];
  if (!slots.any((Slot slot) => slot.name == name)) {
    slots.add(Slot(name: name, value: value));
  }
  return _withSlots(proposal, slots);
}

/// Resolves a spoken product name the way the extractor does.
///
/// The frozen answer is a name, so it goes through the same normalizer and the same
/// longest-match resolver as an utterance. An answer the catalog does not know
/// resolves to null and the doubt stays standing, which fails the case instead of
/// inventing a product.
ProductSnapshot? _resolve(
  Object? value,
  ProductResolver resolver,
  TextNormalizer normalizer,
) {
  if (value is ProductSnapshot) {
    return value;
  }
  if (value is! String) {
    return null;
  }
  final NormalizedText normalized = normalizer.normalize(value);
  if (normalized.isEmpty) {
    return null;
  }
  return resolver.matchAt(normalized.tokens, 0)?.resolution.product;
}

CommandProposal _withSlots(CommandProposal proposal, List<Slot> slots) {
  return CommandProposal(
    intentId: proposal.intentId,
    slots: slots,
    doubts: proposal.doubts,
    origin: proposal.origin,
  );
}

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
