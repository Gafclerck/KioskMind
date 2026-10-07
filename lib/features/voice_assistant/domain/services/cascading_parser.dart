import 'dart:async';

import '../entities/command_proposal.dart';
import '../entities/parse_route.dart';
import '../ports/cloud_intent_parser.dart';
import '../ports/intent_parser.dart';
import '../ports/parse_outcome_journal.dart';
import 'circuit_breaker.dart';

/// Orchestrates utterance interpretation across cloud (T2) and local (T1) parsers.
///
/// When the circuit breaker allows an attempt, it gives the cloud parser a strict
/// time budget. If the cloud call succeeds and returns a proposal, the circuit
/// breaker records success. If the circuit is open, or the cloud call times out or
/// fails, the parser falls back immediately to the local rule-based parser on the
/// exact same transcript.
///
/// Every one of those routes ends in the same thing the merchant hears, so each of
/// them is also recorded in [journal]. Falling back silently is what made this
/// undiagnosable: a merchant with a bad key, a merchant with no network and a
/// merchant whose model answered late all sounded identical, and all three were
/// reported as the model not understanding the words.
final class CascadingParser implements IntentParser {
  CascadingParser({
    required this.local,
    required this.cloud,
    required this.circuitBreaker,
    this.journal,
      Duration? timeBudget,
  }) : timeBudget = timeBudget ?? _defaultTimeBudget;

  final IntentParser local;
  final CloudIntentParser cloud;
  final CircuitBreaker circuitBreaker;

  /// Where the route taken is recorded. Optional so a test can drive the cascade
  /// without one, and so the cascade can be built in a context that does not care.
  final ParseOutcomeJournal? journal;

  Duration timeBudget;

  static const Duration _defaultTimeBudget = Duration(milliseconds: 4500);
  static const Duration _remoteTimeBudget = Duration(milliseconds: 4500);
  static const Duration _localCriticalTimeBudget = Duration(milliseconds: 3500);

  void setTimeBudget({
    required bool isRemoteCloud,
    required bool isLocalCriticalPath,
  }) {
    if (isRemoteCloud) {
      timeBudget = _remoteTimeBudget;
      return;
    }
    if (isLocalCriticalPath) {
      timeBudget = _localCriticalTimeBudget;
      return;
    }
    timeBudget = _defaultTimeBudget;
  }

  @override
  Future<CommandProposal> parse(String raw) async {
    if (!circuitBreaker.canAttempt()) {
      return _local(raw, ParseRouteReason.circuitOpen);
    }
    try {
      final CommandProposal? remote = await cloud
          .parse(raw)
          .timeout(timeBudget);
      if (remote != null) {
        circuitBreaker.recordSuccess();
        journal?.record(
          ParseRouteEvent(
            utterance: raw,
            reason: ParseRouteReason.cloudAnswered,
          ),
        );
        return remote;
      }
      // An answer the remote could not use is the remote's news, not the route's, and
      // it has already been written down with the reason. The cascade adds nothing
      // here on purpose: two lines for one failure would put the coarse reason on top
      // of the precise one, since the history reads newest first.
      circuitBreaker.recordFailure();
    } on TimeoutException {
      circuitBreaker.recordFailure();
      journal?.record(
        ParseRouteEvent(
          utterance: raw,
          reason: ParseRouteReason.timeout,
          detail: 'budget ${timeBudget.inMilliseconds} ms',
        ),
      );
    } catch (error) {
      circuitBreaker.recordFailure();
      journal?.record(
        ParseRouteEvent(
          utterance: raw,
          reason: ParseRouteReason.unreachable,
          detail: '$error',
        ),
      );
    }
    return local.parse(raw);
  }

  /// The route the rules parser answers, recorded with the reason it was chosen.
  ///
  /// [reason] is not optional here on purpose: a fallback that nobody can name is how
  /// a device ends up answering from the rules forever while looking configured.
  ///
  /// Only the two routes that never reach the remote are labelled this way. Falling
  /// back after a remote attempt is left unlabelled, because the attempt already said
  /// why it failed and saying it twice would be two truths about one utterance.
  FutureOr<CommandProposal> _local(String raw, ParseRouteReason reason) {
    journal?.record(ParseRouteEvent(utterance: raw, reason: reason));
    return local.parse(raw);
  }
}
