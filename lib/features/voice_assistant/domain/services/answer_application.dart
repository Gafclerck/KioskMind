import '../entities/command_proposal.dart';
import '../entities/doubt.dart';
import '../entities/intent_definition.dart';
import '../entities/product_snapshot.dart';
import '../entities/slot.dart';
import '../ports/spoken_product_resolver.dart';

/// Applies one answer of the merchant to the proposal the question was asked about.
///
/// A question exists because an utterance left something out. When the merchant
/// answers, the answer does not replace the utterance, it completes it: naming the
/// product of "vendu deux sachets" must keep the two, and answering a quantity must
/// keep the product. That is what [Doubt.partial] carries, and this service is the
/// only place that reads it.
///
/// Three rules, and no more:
///
/// - the answer fills the doubt it was asked about, and leaves every other doubt
///   standing, so a refusal never turns into an execution by naming its product;
/// - what the merchant already said about the line is kept, never overwritten;
/// - an answer the proposal cannot receive settles nothing. The doubt stays and the
///   merchant is asked again, which fails a test case rather than executing on a slot
///   nobody filled.
final class AnswerApplication {
  const AnswerApplication({required this.intents, required this.resolver});

  /// The two doubts a confirmation is answered by. A confirmation asks the merchant
  /// to say yes, so it settles both of them or neither.
  static const Set<DoubtKind> _confirming = <DoubtKind>{
    DoubtKind.amountMismatch,
    DoubtKind.implausibleQuantity,
  };

  final IntentCatalog intents;
  final SpokenProductResolver resolver;

  /// [proposal] with the answer [value] applied to the doubt [asked].
  CommandProposal apply(
    CommandProposal proposal, {
    required DoubtKind asked,
    required Object? value,
  }) {
    if (_confirming.contains(asked)) {
      return _settle(proposal, _confirming);
    }
    final IntentDefinition? definition = intents.byId(proposal.intentId);
    if (definition == null) {
      return proposal;
    }
    if (_isProductDoubt(asked)) {
      return _answerProduct(proposal, asked, value, definition);
    }
    if (_isQuantityDoubt(asked)) {
      return _answerQuantity(proposal, asked, value);
    }
    return proposal;
  }

  CommandProposal _answerProduct(
    CommandProposal proposal,
    DoubtKind asked,
    Object? value,
    IntentDefinition definition,
  ) {
    final ProductSnapshot? product = _resolve(value);
    if (product == null) {
      return proposal;
    }
    return _settle(
      _withProduct(proposal, product, intent: definition, asked: asked),
      <DoubtKind>{asked},
    );
  }

  CommandProposal _answerQuantity(
    CommandProposal proposal,
    DoubtKind asked,
    Object? value,
  ) {
    final List<ItemMention>? lines = proposal.valueOf<List<ItemMention>>(
      kItemsSlot,
    );
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

  /// The product the answer names, whichever shape the answer takes.
  ProductSnapshot? _resolve(Object? value) {
    if (value is ProductSnapshot) {
      return value;
    }
    if (value is! String) {
      return null;
    }
    return resolver.resolve(value);
  }

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
    final bool lineBased = intent.slots.any(
      (SlotDefinition slot) => slot.isItemList,
    );
    if (!lineBased) {
      return _withSlot(proposal, kProductIdSlot, product.id);
    }
    final List<ItemMention>? lines = proposal.valueOf<List<ItemMention>>(
      kItemsSlot,
    );
    final PartialLine? said = _partialLineOf(proposal, asked);
    return _withSlot(proposal, kItemsSlot, <ItemMention>[
      ItemMention(
        product: product,
        qty: said?.qty ?? lines?.first.qty ?? 1,
        spokenAmount: lines?.first.spokenAmount,
      ),
      ...lines?.skip(1) ?? const <ItemMention>[],
    ]);
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

  /// Removes the doubts an answer answered, leaving every other doubt in place.
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
    return CommandProposal(
      intentId: proposal.intentId,
      slots: slots,
      doubts: proposal.doubts,
      origin: proposal.origin,
    );
  }

  static bool _isProductDoubt(DoubtKind doubt) =>
      doubt == DoubtKind.ambiguousProduct ||
      doubt == DoubtKind.unknownProduct ||
      doubt == DoubtKind.missingProduct;

  static bool _isQuantityDoubt(DoubtKind doubt) =>
      doubt == DoubtKind.missingQuantity ||
      doubt == DoubtKind.undeterminedQuantity;
}
