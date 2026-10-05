import '../entities/fact_result.dart';

/// Port for formulating natural language responses from structured execution facts.
///
/// Ported from assistantv3 `Formulator`: replaces rigid static concatenation
/// with fluid, conversational sentences while preserving strict factual truth.
abstract interface class MessageFormulator {
  /// Formulates a natural, polite and concise sentence based on [facts].
  ///
  /// If the formulation fails, times out, or violates [FactPreservingGuard],
  /// implementations must safely return [staticFallback].
  Future<String> formulate({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  });

  /// Synchronous formulation for instant zero-latency rendering.
  String formatSync({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  });
}
