import '../../domain/entities/fact_result.dart';
import '../../domain/ports/message_formulator.dart';
import '../../domain/services/circuit_breaker.dart';
import 'offline_natural_formulator.dart';

/// Orchestrates response formulation across Cloud AI and Offline Local engines.
///
/// Seamlessly delivers:
/// - Fluid, contextualized West African conversational AI when the attempt succeeds.
/// - Instant, natural, zero-latency template variations on failure.
/// - Unbreakable fallback to deterministic static text under any circumstance.
final class CascadingMessageFormulator implements MessageFormulator {
  CascadingMessageFormulator({
    required this.aiFormulator,
    MessageFormulator? offlineFormulator,
    this.circuitBreaker,
  }) : offlineFormulator =
           offlineFormulator ?? const OfflineNaturalFormulator();

  final MessageFormulator aiFormulator;
  final MessageFormulator offlineFormulator;
  final CircuitBreaker? circuitBreaker;

  @override
  Future<String> formulate({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) async {
    // 1. Generate the offline natural formulation first as the resilient local baseline
    final String localNatural = await offlineFormulator.formulate(
      userUtterance: userUtterance,
      facts: facts,
      staticFallback: staticFallback,
    );

    // 2. Attempt the AI formulation when the circuit breaker allows it
    final bool canAttempt =
        circuitBreaker == null || circuitBreaker!.canAttempt();
    if (!canAttempt) {
      return localNatural;
    }

    try {
      final String aiGenerated = await aiFormulator.formulate(
        userUtterance: userUtterance,
        facts: facts,
        staticFallback: localNatural,
      );

      if (aiGenerated.isNotEmpty && aiGenerated != localNatural) {
        circuitBreaker?.recordSuccess();
        return aiGenerated;
      }
    } catch (_) {
      circuitBreaker?.recordFailure();
    }

    return localNatural;
  }

  @override
  String formatSync({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) => offlineFormulator.formatSync(
    userUtterance: userUtterance,
    facts: facts,
    staticFallback: staticFallback,
  );
}
