import '../../domain/entities/fact_result.dart';
import '../../domain/ports/connectivity_probe.dart';
import '../../domain/ports/message_formulator.dart';
import '../../domain/services/circuit_breaker.dart';
import 'offline_natural_formulator.dart';

/// Orchestrates response formulation across Cloud AI and Offline Local engines.
///
/// Seamlessly delivers:
/// - Fluid, contextualized West African conversational AI when online.
/// - Instant, natural, zero-latency template variations when offline or on poor network.
/// - Unbreakable fallback to deterministic static text under any circumstance.
final class CascadingMessageFormulator implements MessageFormulator {
  CascadingMessageFormulator({
    required this.aiFormulator,
    required this.connectivity,
    MessageFormulator? offlineFormulator,
    this.circuitBreaker,
  }) : offlineFormulator =
           offlineFormulator ?? const OfflineNaturalFormulator();

  final MessageFormulator aiFormulator;
  final MessageFormulator offlineFormulator;
  final ConnectivityProbe connectivity;
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

    // 2. Check if online connectivity is available and circuit breaker is healthy
    final bool online = await connectivity.isOnline;
    final bool canAttempt =
        circuitBreaker == null || circuitBreaker!.canAttempt();
    if (!online || !canAttempt) {
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
