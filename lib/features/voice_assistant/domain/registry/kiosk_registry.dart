import '../entities/intent_definition.dart';
import 'kiosk_tool_spec.dart';

/// The commands a language model is offered, projected from the catalog.
///
/// The catalog is the only description of a command in the module: this class holds
/// a catalog and derives everything else from it. That is the whole point of it. The
/// registry used to restate fourteen commands in Dart, next to a JSON file that
/// already said the same thing, and the two could disagree about what the shop
/// sells without anything failing until a merchant asked for the command one of
/// them had dropped.
///
/// Three forms come out of it, for the three ways a model is given a command:
///
///  * [buildSystemPrompt] for the prompt mode the app uses today, where the answer
///    is JSON inside a text response;
///  * [toGeminiTools] for native function calling, where the answer is a call the
///    gateway parses;
///  * [toResponseFormatPrompt] and [toPromptDescription], the two sections of the
///    first, kept apart because a caller may want one without the other.
final class KioskRegistry {
  KioskRegistry.fromCatalog(IntentCatalog catalog)
    : _catalog = catalog,
      _tools = <KioskToolSpec>[
        for (final IntentDefinition intent in catalog.intents)
          KioskToolSpec(intent),
      ];

  final IntentCatalog _catalog;
  final List<KioskToolSpec> _tools;

  /// The catalog the commands are read from.
  IntentCatalog get catalog => _catalog;

  /// The tool of that name, or null when the catalog has no such command.
  KioskToolSpec? get(String name) {
    for (final KioskToolSpec tool in _tools) {
      if (tool.name == name) {
        return tool;
      }
    }
    return null;
  }

  /// Every command, in catalog order, which is the order they are offered in.
  List<KioskToolSpec> allTools() =>
      List<KioskToolSpec>.unmodifiable(_tools);

  /// The commands as Gemini / OpenAI compatible function declarations.
  List<Map<String, dynamic>> toGeminiTools() => _tools
      .map((KioskToolSpec tool) => tool.toFunctionDeclaration())
      .toList(growable: false);

  /// One line per command: what it is called and what it does.
  ///
  /// The descriptions come from the catalog and already end in a full stop, so the
  /// separator is added only when one is missing: a doubled stop in a prompt is
  /// noise the model reads as a typo, and a prompt full of typos is a prompt read
  /// less carefully.
  String toPromptDescription() {
    return _tools
        .map((KioskToolSpec tool) => "- '${tool.name}' : ${_sentenceOf(tool)}")
        .join('\n');
  }

  String _sentenceOf(KioskToolSpec tool) {
    final String label = tool.label.trim();
    return label.endsWith('.') ? label : '$label.';
  }

  /// One worked answer per command, shaped by the slots the catalog declares.
  String toResponseFormatPrompt() {
    final StringBuffer buffer = StringBuffer();
    for (final KioskToolSpec tool in _tools) {
      buffer.writeln("- Pour '${tool.name}' :");
      buffer.writeln('  ${tool.formatExample()}');
    }
    return buffer.toString().trim();
  }

  /// The system prompt of the prompt mode: the commands, the grounding rule and
  /// the shape of the answer.
  ///
  /// The grounding rule names the commands it applies to rather than listing them
  /// by hand, because a hand-written list is exactly the copy that goes stale: an
  /// intent added to the catalog would be offered to the model with no instruction
  /// about how to refer to its products.
  String buildSystemPrompt() {
    final List<String> grounded = <String>[
      for (final KioskToolSpec tool in _tools)
        if (tool.referencesExistingProducts) "'${tool.name}'",
    ];
    final StringBuffer prompt = StringBuffer()
      ..writeln(
        "Tu es l'assistant de caisse de KioskMind pour les commerçants "
        "d'Afrique de l'Ouest.",
      )
      ..writeln(
        'Analyse la phrase prononcée par le commerçant et identifie son intention '
        'parmi :',
      )
      ..writeln(toPromptDescription())
      ..writeln()
      ..writeln('RÈGLE D\'ANCRAGE STRICTE (D5) :');
    if (grounded.isNotEmpty) {
      prompt
        ..writeln(
          "Pour les intentions manipulant des produits existants "
          "(${grounded.join(', ')}), tu dois OBLIGATOIREMENT et UNIQUEMENT "
          "utiliser les 'id' des produits qui figurent explicitement dans le "
          'catalogue fourni.',
        )
        ..writeln(
          "N'invente JAMAIS d'identifiant de produit qui n'est pas dans le "
          'catalogue.',
        );
    }
    prompt
      ..writeln(
        "Pour toute autre intention, recopie dans 'name' le nom prononcé par le "
        'commerçant.',
      )
      ..writeln()
      ..writeln('FORMAT DE RÉPONSE OBLIGATOIRE EN JSON PUR :')
      ..writeln(toResponseFormatPrompt());
    return prompt.toString().trim();
  }
}
