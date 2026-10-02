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
enum SlotType {
  productName('product_name'),
  quantity('quantity'),
  unit('unit'),
  money('money'),
  itemList('item_list');

  const SlotType(this.code);

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
}
