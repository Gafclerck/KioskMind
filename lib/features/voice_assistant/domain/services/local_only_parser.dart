import 'dart:async';

import '../entities/command_proposal.dart';
import '../entities/parse_route.dart';
import '../ports/intent_parser.dart';
import '../ports/parse_outcome_journal.dart';

/// The rules parser standing in for a cloud that was never tried, and saying why.
///
/// [CascadingParser] is the right orchestrator when there is something to
/// orchestrate. When there is not, the composition root used to hand back the bare
/// rules parser, and a bare rules parser is the most expensive kind of silence: the
/// device looks configured, the merchant hears the assistant working, and the only
/// commands reachable are the handful the rules can hear on their own.
///
/// Wrapping it costs one object and buys the difference between "the assistant does
/// not know this word" and "the assistant was never asked". The second is a
/// deployment fault, and it is invisible everywhere except here.
final class LocalOnlyParser implements IntentParser {
  LocalOnlyParser({required this.local, required this.reason, this.journal});

  final IntentParser local;

  /// Why the cloud was not tried: [ParseRouteReason.localOnly] when the build turned
  /// it off on purpose, [ParseRouteReason.noCredential] when it was meant to be on
  /// and had no key to go with it.
  final ParseRouteReason reason;

  final ParseOutcomeJournal? journal;

  @override
  FutureOr<CommandProposal> parse(String raw) {
    journal?.record(ParseRouteEvent(utterance: raw, reason: reason));
    return local.parse(raw);
  }
}
