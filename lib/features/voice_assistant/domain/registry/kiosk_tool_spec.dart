import '../entities/intent_definition.dart';

/// One command as a language model is offered it.
///
/// A projection of [IntentDefinition] and nothing more. Everything said here is read
/// off the catalog JSON, so adding a command means adding it to
/// `voice/intent_catalog.json` and nothing here has to be kept in step. The class
/// holds no description of its own: a second copy of what a command is would be a
/// second truth, and the two would disagree the first time one of them was edited.
final class KioskToolSpec {
  const KioskToolSpec(this.intent);

  final IntentDefinition intent;

  /// The catalog identifier, which is also the `intentId` of the answer.
  String get name => intent.id;

  /// What the command does, in the catalog's own words.
  String get label => intent.description;

  /// One way of saying it, used as the worked example in the prompt.
  String? get example => intent.examples.isEmpty ? null : intent.examples.first;

  /// Whether the command works on a product the shop already sells, which decides
  /// whether the grounding rule has to name it.
  bool get referencesExistingProducts => intent.referencesExistingProducts;

  /// The declaration both Gemini and OpenAI compatible gateways accept.
  ///
  /// Types and required flags come from the declared slots, so a slot the catalog
  /// adds is described to the model without a line of Dart changing.
  Map<String, dynamic> toFunctionDeclaration() {
    return <String, dynamic>{
      'name': name,
      'description': _declarationDescription(),
      'parameters': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          for (final SlotDefinition slot in intent.slots)
            slot.name: _schemaOf(slot),
        },
        'required': <String>[
          for (final SlotDefinition slot in intent.slots)
            if (slot.required) slot.name,
        ],
      },
    };
  }

  /// A worked answer for the prompt, shaped by the declared slots.
  ///
  /// Optional slots appear too, marked as such, because the model must know it may
  /// omit them: a prompt showing only the required fields teaches a model to leave
  /// a spoken price out. The marker is on the line slots too, because a line of a
  /// sale carries an optional announced price exactly as a command carries an
  /// optional date.
  String formatExample() {
    if (intent.slots.isEmpty) {
      return '{"intentId": "$name"}';
    }
    final String fields = intent.slots
        .map((SlotDefinition slot) => _exampleFieldOf(slot))
        .join(', ');
    return '{"intentId": "$name", $fields}';
  }

  /// The description handed to the model: what the command does, and how it is said.
  String _declarationDescription() {
    final String? said = example;
    return said == null ? label : '$label (ex: "$said")';
  }

  /// The JSON schema of one declared slot, list slots carrying their line schema.
  Map<String, dynamic> _schemaOf(SlotDefinition slot) {
    if (!slot.isItemList) {
      return <String, dynamic>{
        'type': _jsonTypeOf(slot.type),
        'description': slot.description,
      };
    }
    return <String, dynamic>{
      'type': 'array',
      'description': slot.description,
      'items': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          for (final SlotDefinition line in slot.lineSlots)
            line.name: <String, dynamic>{
              'type': _jsonTypeOf(line.type),
              'description': line.description,
            },
        },
        'required': <String>[
          for (final SlotDefinition line in slot.lineSlots)
            if (line.required) line.name,
        ],
      },
    };
  }

  /// The JSON type a slot carries.
  ///
  /// A product reference is a string because it is an identifier copied from the
  /// catalog, and every count and amount is a number because the parser reads it as
  /// one and a quoted figure would be dropped rather than rounded.
  String _jsonTypeOf(SlotType type) {
    return switch (type) {
      SlotType.productReference ||
      SlotType.unit ||
      SlotType.string => 'string',
      SlotType.quantity || SlotType.money || SlotType.number => 'number',
      SlotType.itemList => 'array',
    };
  }

  /// One `"name": value` pair, marked when the merchant may leave it out.
  String _exampleFieldOf(SlotDefinition slot) {
    final String field = '"${slot.name}": ${_exampleValueOf(slot)}';
    return slot.required ? field : '$field /* optionnel */';
  }

  /// The value shown for a slot in the worked example.
  ///
  /// Chosen per type so the example is a shape the model copies rather than a
  /// shape it has to interpret: a number where the field is a number, and the
  /// literal token the catalog says a product is referred to by.
  String _exampleValueOf(SlotDefinition slot) {
    if (slot.isItemList) {
      if (slot.lineSlots.isEmpty) {
        return '[]';
      }
      final String lines = slot.lineSlots
          .map(_exampleFieldOf)
          .join(', ');
      return '[{$lines}]';
    }
    return switch (slot.type) {
      SlotType.productReference => '"<id_catalogue>"',
      SlotType.quantity || SlotType.money || SlotType.number => '0',
      SlotType.unit || SlotType.string => '"..."',
      SlotType.itemList => '[]',
    };
  }

  @override
  String toString() => 'KioskToolSpec($name)';
}
