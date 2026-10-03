import '../entities/command_proposal.dart';

/// Interprets an utterance using the remote cloud language model (T2).
///
/// Implementations call the Cloud Function backend. If remote parsing fails,
/// times out or returns an unroutable response, implementations return null
/// or throw so the cascade falls back cleanly to the rule-based parser.
abstract interface class CloudIntentParser {
  /// Interprets [raw] via the remote cloud service.
  ///
  /// Returns null when the remote model could not identify a valid proposal.
  Future<CommandProposal?> parse(String raw);
}
