import 'dart:async';

import '../entities/fact_result.dart';
import '../policies/confirmation_policy.dart';
import '../policies/precheck_verdict.dart';

typedef KioskToolHandler =
    Future<FactResult> Function(Map<String, dynamic> params);
typedef KioskPrecheck =
    FutureOr<PrecheckVerdict> Function(Map<String, dynamic> params);

/// Specification of an action/tool in the KioskMind assistant.
///
/// Ported from assistantv3 `ToolSpec`:
/// Provides complete encapsulation of an action: its handler, confirmation policy,
/// domain precheck, examples, and fallback declaration keywords.
final class KioskToolSpec {
  const KioskToolSpec({
    required this.name,
    required this.label,
    required this.example,
    required this.handler,
    this.confirmation = const NeverConfirmation(),
    this.precheck,
    this.declarationKeywords = const <String>{},
    this.paramLabels = const <String, String>{},
    this.jsonFormatExample,
  });

  /// Unique name (e.g. 'record_sale', 'query_stock', 'record_client_debt').
  final String name;

  /// User-facing label (e.g. 'Enregistrer une vente').
  final String label;

  /// Canonical spoken example (e.g. 'vends deux savons').
  final String example;

  /// The execution handler returning verifiable [FactResult].
  final KioskToolHandler handler;

  /// Confirmation policy (Always, Never, Threshold, Predicate).
  final ConfirmationPolicy confirmation;

  /// Precheck verification executed before confirmation or execution.
  final KioskPrecheck? precheck;

  /// Keywords for fallback intent detection (like DeclarationSpec in assistantv3).
  final Set<String> declarationKeywords;

  /// Parameter labels for readable confirmation summaries.
  final Map<String, String> paramLabels;

  /// Canonical JSON format example for LLM prompting.
  final String? jsonFormatExample;

  /// Returns the formatted JSON example, either custom or computed from paramLabels.
  String formatExample() {
    if (jsonFormatExample != null && jsonFormatExample!.isNotEmpty) {
      return jsonFormatExample!;
    }
    if (paramLabels.isEmpty) {
      return '{"intentId": "$name"}';
    }
    final String params = paramLabels.keys
        .map((String k) => '"$k": ...')
        .join(', ');
    return '{"intentId": "$name", $params}';
  }

  /// Exports this tool as a standard Gemini / OpenAI compatible Tool Declaration.
  Map<String, dynamic> toFunctionDeclaration() {
    return <String, dynamic>{
      'name': name,
      'description': '$label (ex: "$example")',
      'parameters': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          for (final MapEntry<String, String> entry in paramLabels.entries)
            entry.key: <String, dynamic>{
              'type': 'string',
              'description': entry.value,
            },
        },
      },
    };
  }

  @override
  String toString() => 'KioskToolSpec($name)';
}
