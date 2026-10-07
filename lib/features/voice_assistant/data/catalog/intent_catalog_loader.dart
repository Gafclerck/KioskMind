import 'dart:convert';

import '../../domain/entities/intent_definition.dart';
import '../../domain/ports/intent_handler.dart';

/// Path of the intent catalog shipped with the app, declared as an asset.
const String intentCatalogAsset = 'voice/intent_catalog.json';

/// Reads and validates the intent catalog.
///
/// Takes the raw JSON rather than loading the asset, so the same code is
/// exercised by the unit tests, by `voice_eval` and at runtime. Validation is
/// strict and every failure is loud: a catalog that half-parses would make the
/// rule parser and the LLM tools disagree about what commands exist, and that
/// kind of drift is invisible until a merchant asks for a command that silently
/// does nothing.
IntentCatalog parseIntentCatalog(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Catalogue racine: objet JSON attendu');
  }
  if (_requireInt(decoded, 'version') != 1) {
    throw FormatException(
      'Catalogue "version": 1 attendu, obtenu ${decoded['version']}',
    );
  }
  _requireNonEmptyString(decoded, 'currency');

  final Object? rawIntents = decoded['intents'];
  if (rawIntents is! List<Object?>) {
    throw const FormatException('Catalogue "intents": liste attendue');
  }
  if (rawIntents.isEmpty) {
    throw const FormatException('Catalogue "intents": liste vide');
  }
  return IntentCatalog(
    currency: decoded['currency']! as String,
    intents: _parseIntents(rawIntents),
  );
}

List<IntentDefinition> _parseIntents(List<Object?> rawIntents) {
  final List<IntentDefinition> intents = <IntentDefinition>[];
  final Set<String> seenIds = <String>{};
  for (int index = 0; index < rawIntents.length; index++) {
    final Object? entry = rawIntents[index];
    if (entry is! Map<String, Object?>) {
      throw FormatException('Intent #$index: objet JSON attendu');
    }
    final IntentDefinition intent = _parseIntent(entry, index);
    if (!seenIds.add(intent.id)) {
      throw FormatException(
        'Intent #$index: identifiant duplique "${intent.id}"',
      );
    }
    if (!kSupportedIntentIds.contains(intent.id)) {
      throw FormatException(
        'Intent "${intent.id}": aucun port ne sait l executer',
      );
    }
    if (intent.handler != intent.id) {
      throw FormatException(
        'Intent "${intent.id}": handler "${intent.handler}" incoherent, '
        'un intent et son handler portent le meme identifiant',
      );
    }
    intents.add(intent);
  }
  _requireEveryIntentPresent(intents);
  return intents;
}

/// Every port must be reachable, otherwise a command silently loses its path.
void _requireEveryIntentPresent(List<IntentDefinition> intents) {
  final Set<String> declared = <String>{
    for (final IntentDefinition intent in intents) intent.id,
  };
  final Set<String> missing = kSupportedIntentIds.difference(declared);
  if (missing.isNotEmpty) {
    throw FormatException(
      'Intent(s) declare(s) dans le code mais absents du catalogue: '
      '${(missing.toList()..sort()).join(', ')}',
    );
  }
}

IntentDefinition _parseIntent(Map<String, Object?> json, int index) {
  final String id = _requireNonEmptyString(json, 'id');
  return IntentDefinition(
    id: id,
    handler: _requireNonEmptyString(json, 'handler', of: id),
    risk: _parseRisk(json['risk'], id),
    description: _requireNonEmptyString(json, 'description', of: id),
    triggers: _parseStringList(
      json['triggers'],
      '$id.triggers',
      normalized: true,
    ),
    examples: _parseStringList(json['examples'], '$id.examples'),
    slots: _parseSlots(json['slots'], id),
    referencePrice: _parseReferencePrice(json['referencePrice'], id),
    onlineOnly: json['onlineOnly'] as bool? ?? false,
  );
}

/// The optional `referencePrice`, read by code rather than by name.
///
/// A command that takes no amount declares nothing and gets
/// [ReferencePrice.none], so an amount spoken on it is never doubted.
ReferencePrice _parseReferencePrice(Object? raw, String intentId) {
  if (raw == null) {
    return ReferencePrice.none;
  }
  for (final ReferencePrice price in ReferencePrice.values) {
    if (price.code == raw) {
      return price;
    }
  }
  final List<String> allowed = <String>[
    for (final ReferencePrice price in ReferencePrice.values) price.code,
  ];
  throw FormatException(
    'Intent "$intentId": "referencePrice" invalide ($raw), '
    'parmi ${allowed.join(', ')}',
  );
}

IntentRisk _parseRisk(Object? raw, String intentId) {
  for (final IntentRisk risk in IntentRisk.values) {
    if (risk.code == raw) {
      return risk;
    }
  }
  final List<String> allowed = <String>[
    for (final IntentRisk risk in IntentRisk.values) risk.code,
  ];
  throw FormatException(
    'Intent "$intentId": "risk" invalide ($raw), parmi ${allowed.join(', ')}',
  );
}

/// A list the rule parser and the LLM both read.
///
/// Neither list may be empty: an intent without a trigger cannot be recognized
/// offline, and one without an example gives the LLM nothing to imitate.
///
/// [normalized] asks for the form the normalizer produces, lowercase and without
/// accents, because the rule parser matches triggers literally.
List<String> _parseStringList(
  Object? raw,
  String label, {
  bool normalized = false,
}) {
  if (raw is! List<Object?>) {
    throw FormatException('$label: liste attendue');
  }
  if (raw.isEmpty) {
    throw FormatException('$label: liste vide');
  }
  final List<String> values = <String>[];
  for (final Object? value in raw) {
    final String text = _requireNonEmptyStringValue(value, label);
    if (values.contains(text)) {
      throw FormatException('$label: doublon "$text"');
    }
    if (normalized && text != _normalize(text)) {
      throw FormatException(
        '$label: "$text" n est pas normalise (minuscules, sans accent)',
      );
    }
    values.add(text);
  }
  return values;
}

List<SlotDefinition> _parseSlots(Object? raw, String intentId) {
  if (raw is! List<Object?>) {
    throw FormatException('Intent "$intentId": "slots" liste attendue');
  }
  final List<SlotDefinition> slots = <SlotDefinition>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) {
      throw FormatException('Intent "$intentId": slot en objet JSON attendu');
    }
    slots.add(_parseSlot(entry, intentId));
  }
  return slots;
}

SlotDefinition _parseSlot(Map<String, Object?> json, String intentId) {
  final String label = 'Intent "$intentId".slot "${json['name']}"';
  final String name = _requireNonEmptyString(json, 'name', of: intentId);
  final SlotType type = _parseSlotType(json['type'], name);
  final Object? rawRequired = json['required'];
  if (rawRequired is! bool) {
    throw FormatException('$label: "required" booleen attendu');
  }
  return SlotDefinition(
    name: name,
    type: type,
    required: rawRequired,
    description: _requireNonEmptyString(json, 'description', of: intentId),
    lineSlots: _parseLineSlots(json['lineSlots'], name, type),
  );
}

/// The shape of a slot is the whole point of the catalog, so a missing or
/// unexpected `lineSlots` is refused rather than defaulted.
List<SlotDefinition> _parseLineSlots(
  Object? raw,
  String slotName,
  SlotType type,
) {
  if (type != SlotType.itemList) {
    // An empty list is accepted so an author can write the same shape everywhere,
    // but a non-empty one would claim a list the slot does not have.
    if (raw != null && (raw is! List<Object?> || raw.isNotEmpty)) {
      throw FormatException(
        'Slot "$slotName": "lineSlots" non vide n a de sens que sur un item_list',
      );
    }
    return const <SlotDefinition>[];
  }
  if (raw is! List<Object?> || raw.isEmpty) {
    throw FormatException('Slot "$slotName": "lineSlots" non vide attendu');
  }
  return <SlotDefinition>[
    for (final Object? entry in raw)
      if (entry is Map<String, Object?>)
        _parseSlot(entry, slotName)
      else
        throw FormatException('Slot "$slotName": ligne de slot invalide'),
  ];
}

SlotType _parseSlotType(Object? raw, String slotName) {
  for (final SlotType type in SlotType.values) {
    if (type.code == raw) {
      return type;
    }
  }
  final List<String> allowed = <String>[
    for (final SlotType type in SlotType.values) type.code,
  ];
  throw FormatException(
    'Slot "$slotName": "type" invalide ($raw), parmi ${allowed.join(', ')}',
  );
}

String _normalize(String text) {
  const String from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const String to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final StringBuffer buffer = StringBuffer();
  for (final int rune in text.runes) {
    final String character = String.fromCharCode(rune);
    final int index = from.indexOf(character);
    buffer.write(index < 0 ? character : to[index]);
  }
  return buffer.toString().toLowerCase();
}

String _requireNonEmptyString(
  Map<String, Object?> json,
  String key, {
  String? of,
}) {
  final String label = of == null ? '"$key"' : '"$key" de $of';
  return _requireNonEmptyStringValue(json[key], label);
}

String _requireNonEmptyStringValue(Object? value, String label) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$label: texte non vide attendu, obtenu $value');
}

int _requireInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  if (value is double && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('"$key": entier attendu, obtenu $value');
}
