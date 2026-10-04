import 'kiosk_tool_spec.dart';

/// Registry of tools/actions available in the KioskMind assistant.
///
/// Ported from assistantv3 `Registry`:
/// Extensibility port allowing new business actions (sales, restock, stock query,
/// customer debt, alerts) to be plugged in without modifying the engine.
final class KioskRegistry {
  final Map<String, KioskToolSpec> _tools = <String, KioskToolSpec>{};

  /// Registers a tool spec into the registry.
  /// Throws [StateError] if a tool with the same name is already registered.
  void register(KioskToolSpec spec) {
    if (_tools.containsKey(spec.name)) {
      throw StateError('Outil déjà enregistré dans le registre: ${spec.name}');
    }
    _tools[spec.name] = spec;
  }

  /// Gets a tool by its unique name.
  KioskToolSpec? get(String name) => _tools[name];

  /// Returns all registered tools.
  List<KioskToolSpec> allTools() =>
      List<KioskToolSpec>.unmodifiable(_tools.values);

  /// Converts all registered tools into a standard Gemini Function Calling declarations list.
  List<Map<String, dynamic>> toGeminiTools() => _tools.values
      .map((KioskToolSpec s) => s.toFunctionDeclaration())
      .toList();

  /// Converts all registered tools into a concise prompt description for LLM system instructions.
  String toPromptDescription() {
    final StringBuffer buffer = StringBuffer();
    for (final KioskToolSpec spec in _tools.values) {
      buffer.writeln(
        '- \'${spec.name}\' : ${spec.label} (ex: "${spec.example}")',
      );
    }
    return buffer.toString().trim();
  }

  /// Fallback detector (DeclarationSpec from assistantv3):
  /// If the NLU fails to match, inspects utterance tokens for declared tool keywords.
  KioskToolSpec? detectDeclaration(String utterance) {
    final String clean = utterance.toLowerCase();
    for (final KioskToolSpec spec in _tools.values) {
      if (spec.declarationKeywords.isEmpty) continue;
      for (final String keyword in spec.declarationKeywords) {
        if (clean.contains(keyword.toLowerCase())) {
          return spec;
        }
      }
    }
    return null;
  }

  /// Clears the registry (useful for testing and hot reload).
  void clear() {
    _tools.clear();
  }
}
