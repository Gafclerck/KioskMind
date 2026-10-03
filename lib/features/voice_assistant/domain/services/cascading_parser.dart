import 'dart:async';

import '../entities/command_proposal.dart';
import '../ports/cloud_intent_parser.dart';
import '../ports/connectivity_probe.dart';
import '../ports/intent_parser.dart';
import 'circuit_breaker.dart';

/// Orchestrates utterance interpretation across cloud (T2) and local (T1) parsers.
///
/// When the device is online and the circuit breaker allows an attempt, it gives
/// the cloud parser a strict time budget. If the cloud call succeeds and returns a
/// proposal, the circuit breaker records success. If the device is offline, the
/// circuit is open, or the cloud call times out or fails, the parser falls back
/// immediately to the local rule-based parser on the exact same transcript.
final class CascadingParser implements IntentParser {
  CascadingParser({
    required this.local,
    required this.cloud,
    required this.connectivity,
    required this.circuitBreaker,
    this.timeBudget = const Duration(milliseconds: 2000),
  });

  final IntentParser local;
  final CloudIntentParser cloud;
  final ConnectivityProbe connectivity;
  final CircuitBreaker circuitBreaker;
  final Duration timeBudget;

  @override
  Future<CommandProposal> parse(String raw) async {
    final bool online = await connectivity.isOnline;
    if (!online || !circuitBreaker.canAttempt()) {
      return local.parse(raw);
    }
    try {
      final CommandProposal? remote = await cloud
          .parse(raw)
          .timeout(timeBudget);
      if (remote != null) {
        circuitBreaker.recordSuccess();
        return remote;
      }
      circuitBreaker.recordFailure();
    } catch (_) {
      circuitBreaker.recordFailure();
    }
    return local.parse(raw);
  }
}
