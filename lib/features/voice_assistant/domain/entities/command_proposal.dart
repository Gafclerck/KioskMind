import 'doubt.dart';
import 'slot.dart';

/// Which parser produced a proposal.
///
/// The origin travels with the proposal so the decision policy can weigh it: an
/// LLM proposal is cross-checked, a rule proposal is already grounded.
enum ProposalOrigin {
  rules('rules'),
  languageModel('llm');

  const ProposalOrigin(this.code);

  final String code;
}

/// Placeholder for the sale the session voice is cancelling.
///
/// `cancel_last_sale` has no slot, so the identifier can only come from the
/// session. The session substitutes the real identifier before the call; the
/// golden set compares this placeholder.
const String kLastSaleIdPlaceholder = r'$lastSaleId';

/// Intent of a proposal that names no command at all.
///
/// A refusal and an utterance about the weather both land here: the parser
/// reports why in its doubts, and the decision policy picks the message.
const String kNoIntent = '';

/// What a parser understood of one utterance.
///
/// A proposal is immutable and always carries an intent and its slots. What it
/// does not carry is a verdict: whether it may execute is the decision policy's
/// job, not the parser's. That separation is what lets the same proposal be
/// re-decided under a different risk tolerance without parsing again.
final class CommandProposal {
  const CommandProposal({
    required this.intentId,
    required this.slots,
    required this.doubts,
    required this.origin,
  });

  const CommandProposal.rules({
    required this.intentId,
    required this.slots,
    this.doubts = const <Doubt>[],
  }) : origin = ProposalOrigin.rules;

  /// One of the ids of the intent catalog.
  final String intentId;

  final List<Slot> slots;

  /// Everything that keeps the proposal from being executed as it stands.
  final List<Doubt> doubts;

  final ProposalOrigin origin;

  bool get isComplete => doubts.isEmpty;

  T? valueOf<T>(String name) {
    for (final Slot slot in slots) {
      if (slot.name == name) {
        final Object? value = slot.value;
        return value is T ? value : null;
      }
    }
    return null;
  }

  bool hasDoubt(DoubtKind kind) {
    for (final Doubt doubt in doubts) {
      if (doubt.kind == kind) {
        return true;
      }
    }
    return false;
  }

  /// The first doubt of that kind, or null.
  Doubt? doubtOf(DoubtKind kind) {
    for (final Doubt doubt in doubts) {
      if (doubt.kind == kind) {
        return doubt;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'CommandProposal($intentId, ${slots.length} slots, ${doubts.length} doubts)';
}
