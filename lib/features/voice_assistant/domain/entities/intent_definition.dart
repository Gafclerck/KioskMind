/// Risk class of an intent, as the decision policy sees it.
///
/// No destructive class exists on purpose: deleting or archiving anything is not
/// reachable by voice in the MVP, so the enum has no value that would express it.
enum IntentRisk {
  read('READ'),
  writeReversible('WRITE_REVERSIBLE'),
  writeSensitive('WRITE_SENSITIVE');

  const IntentRisk(this.code);

  /// The value stored in `voice/intent_catalog.json` and sent to the LLM.
  final String code;

  /// Whether executing the intent writes data.
  bool get isWrite => this != IntentRisk.read;
}

/// What a slot holds. The set is closed: an unknown type is a catalog error, not
/// something to pass through to the LLM.
///
/// [productReference] is named after what it points at rather than after the field
/// that carries it, because the field is `productId` for every intent that takes
/// one and the type says nothing about a name.
enum SlotType {
  productReference('product_reference'),
  quantity('quantity'),
  unit('unit'),
  money('money'),
  itemList('item_list'),
  string('string'),
  number('number');

  const SlotType(this.code);

  final String code;

  /// Whether the slot refers to a product the shop already sells, which is what
  /// the grounding rule (D5) is about.
  bool get referencesProduct => this == SlotType.productReference;
}

/// Which price of the product a spoken amount is compared against.
///
/// Declared by the catalog because it is a business fact, not a code detail:
/// comparing a restock to the sale price would doubt every correct restock, and
/// comparing a sale to the purchase price would doubt the normal case.
enum ReferencePrice {
  /// The intent never takes an amount, so there is nothing to compare.
  none('none'),
  salePrice('sale_price'),
  purchasePrice('purchase_price');

  const ReferencePrice(this.code);

  /// The value stored in `voice/intent_catalog.json`.
  final String code;
}

/// One slot of an intent.
///
/// A slot of type [SlotType.itemList] describes a list of lines and therefore
/// carries [lineSlots], one description per line field. Any other type has an
/// empty `lineSlots`, so a caller never has to handle a missing list.
final class SlotDefinition {
  const SlotDefinition({
    required this.name,
    required this.type,
    required this.required,
    required this.description,
    required this.lineSlots,
  });

  final String name;
  final SlotType type;
  final bool required;

  /// Handed to the LLM as the field description, in French.
  final String description;

  final List<SlotDefinition> lineSlots;

  bool get isItemList => type == SlotType.itemList;
}

/// One intent of the catalog: everything the rule parser (T1) and the LLM tools
/// (T2) need to know about a command, in a single place.
final class IntentDefinition {
  const IntentDefinition({
    required this.id,
    required this.handler,
    required this.risk,
    required this.description,
    required this.triggers,
    required this.examples,
    required this.slots,
    this.referencePrice = ReferencePrice.none,
    this.onlineOnly = false,
  });

  final String id;

  /// The handler that executes it. Must be one of the ids of [VoiceHandlers].
  final String handler;

  final IntentRisk risk;
  final String description;

  /// Lowercase accent-free wordings, matched by the rule parser in 1a.
  final List<String> triggers;

  /// Natural French sentences, shown to the LLM and reused by the test set.
  final List<String> examples;

  final List<SlotDefinition> slots;

  /// Which product price an announced amount is compared against.
  final ReferencePrice referencePrice;

  /// Whether this intent is strictly reserved for the online LLM mode.
  final bool onlineOnly;

  /// Whether running this command takes a list of lines, from the declared shape.
  bool get takesItems => slots.any((SlotDefinition slot) => slot.isItemList);

  /// Whether this command works on a product the shop already sells.
  ///
  /// Read off the declared slots rather than off the identifier: a slot of type
  /// [SlotType.productReference] is a reference into the catalog, and its presence
  /// is exactly what the grounding rule has to mention. Deriving it keeps the rule
  /// true when a command is added instead of quietly leaving it out of the prompt.
  bool get referencesExistingProducts => slots.any(
    (SlotDefinition slot) =>
        slot.type.referencesProduct ||
        slot.lineSlots.any((SlotDefinition line) => line.type.referencesProduct),
  );
}

/// The validated contents of `voice/intent_catalog.json`.
final class IntentCatalog {
  const IntentCatalog({required this.currency, required this.intents});

  /// ISO code, so amounts read by the TTS and written to the recap agree.
  final String currency;

  final List<IntentDefinition> intents;

  /// The intent with that id, or null when the catalog has no such command.
  IntentDefinition? byId(String id) {
    for (final IntentDefinition intent in intents) {
      if (intent.id == id) {
        return intent;
      }
    }
    return null;
  }

  /// Ids in catalog order, which is the order the LLM is offered the tools.
  List<String> get ids => <String>[
    for (final IntentDefinition intent in intents) intent.id,
  ];

  /// Intents available offline.
  List<IntentDefinition> get offlineIntents =>
      intents.where((IntentDefinition intent) => !intent.onlineOnly).toList();

  /// Intents available online (all 14 intents).
  List<IntentDefinition> get onlineIntents => intents;

  /// Intents restricted to online-only execution (10 tools).
  List<IntentDefinition> get onlineOnlyIntents =>
      intents.where((IntentDefinition intent) => intent.onlineOnly).toList();
}
