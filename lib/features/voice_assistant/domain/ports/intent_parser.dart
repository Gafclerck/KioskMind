import '../entities/command_proposal.dart';

/// Reads one utterance into a proposal.
///
/// Two implementations are planned: the rule parser (T1), which is always
/// available, and the language model (T2), in 2b. The domain only ever sees this
/// port, which is what lets the orchestrator offer T2 a time budget and fall back
/// to T1 without anything downstream knowing which one answered.
///
/// A parser reports what it understood and what is missing. It never decides
/// whether the command may run: that is the policy's, and keeping the two apart is
/// what lets the same text be re-judged without being understood again.
abstract interface class IntentParser {
  /// Reads [raw] into a proposal, with no side effect and no verdict.
  CommandProposal parse(String raw);
}
