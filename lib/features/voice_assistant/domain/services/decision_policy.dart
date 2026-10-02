import '../entities/command_proposal.dart';
import '../entities/decision_outcome.dart';
import '../entities/doubt.dart';
import '../entities/intent_definition.dart';

/// Doubts that mean the command must not run, whatever else the proposal says.
///
/// Ordered so the reason reported to the merchant is the same for the same
/// proposal: the first listed doubt present wins.
const List<DoubtKind> kRefusingDoubts = <DoubtKind>[
  DoubtKind.archivedProduct,
  DoubtKind.destructiveRequest,
  DoubtKind.outOfDomain,
  DoubtKind.unboundedScope,
  DoubtKind.noOrderUseCase,
  DoubtKind.invalidQuantity,
];

/// Doubts only the merchant can resolve, by answering a question.
///
/// They outrank the value doubts: an utterance whose product was not understood
/// cannot be confirmed, it has to be asked about first. That precedence is measured
/// on the frozen set (t253 states a missing quantity and an out-of-scope request
/// and is expected as a clarification, not a refusal).
const List<DoubtKind> kClarifyingDoubts = <DoubtKind>[
  DoubtKind.missingProduct,
  DoubtKind.unknownProduct,
  DoubtKind.ambiguousProduct,
  DoubtKind.missingQuantity,
  DoubtKind.undeterminedQuantity,
  DoubtKind.anaphora,
];

/// Doubts about a value the merchant stated, so agreeing is enough.
///
/// The merchant already said the number; the module does not ask it again, it
/// asks whether to apply it as understood.
const List<DoubtKind> kConfirmingDoubts = <DoubtKind>[
  DoubtKind.amountMismatch,
  DoubtKind.implausibleQuantity,
];

/// Turns a proposal into one of five issues. Pure: same inputs, same issue.
///
/// The policy is the only place in the module where "what was heard" becomes
/// "what happens". It reads no clock, touches no handler, and knows nothing about
/// the session: the same proposal is re-decided the same way in a test, in the
/// offline path, and in the live one.
///
/// Its whole behaviour is a lookup on the doubt classes above, then on the risk of
/// the intent. Both tables are data, so adding a doubt or a risk is a line in a
/// list rather than a branch in a condition, and [decision_policy_test.dart]
/// checks that every doubt of [DoubtKind] has a row.
final class DecisionPolicy {
  const DecisionPolicy({required this.catalog});

  /// The intent catalog, for the risk of the intent the proposal names.
  final IntentCatalog catalog;

  Decision decide(CommandProposal proposal) {
    if (proposal.intentId == kNoIntent) {
      return const Decision(
        DecisionOutcome.reject,
        reason: DoubtKind.outOfDomain,
      );
    }
    final IntentDefinition? intent = catalog.byId(proposal.intentId);
    if (intent == null) {
      // A proposal naming an intent the catalog does not describe cannot be
      // checked against anything, and running it would be running a command no
      // one reviewed. Refusing is the only honest issue.
      return const Decision(
        DecisionOutcome.reject,
        reason: DoubtKind.outOfDomain,
      );
    }

    final DoubtKind? refusing = _firstOf(kRefusingDoubts, proposal);
    if (refusing != null) {
      return Decision(DecisionOutcome.reject, reason: refusing);
    }
    final DoubtKind? clarifying = _firstOf(kClarifyingDoubts, proposal);
    if (clarifying != null) {
      return Decision(DecisionOutcome.askClarification, reason: clarifying);
    }
    final DoubtKind? confirming = _firstOf(kConfirmingDoubts, proposal);
    if (confirming != null) {
      return _confirmationOrQuestion(intent, confirming);
    }
    return _cleanIssue(intent);
  }

  /// A doubt about a stated value becomes a confirmation on a write, and a
  /// question on a read.
  ///
  /// Confirming a read would ask the merchant to authorise something that does not
  /// change anything. A read whose amount looks wrong is asked about instead, so
  /// the merchant re-reads the figure instead of pressing a button that changes
  /// nothing.
  Decision _confirmationOrQuestion(IntentDefinition intent, DoubtKind doubt) {
    if (intent.risk.isWrite) {
      return Decision(DecisionOutcome.askConfirmation, reason: doubt);
    }
    return Decision(DecisionOutcome.askClarification, reason: doubt);
  }

  /// What a proposal with no doubt at all deserves.
  ///
  /// The risk alone decides: a read runs, a reversible write runs with an undo
  /// window, and a sensitive write is confirmed before it happens.
  Decision _cleanIssue(IntentDefinition intent) {
    return switch (intent.risk) {
      IntentRisk.read => const Decision(DecisionOutcome.execute),
      IntentRisk.writeReversible => const Decision(
        DecisionOutcome.executeWithUndo,
      ),
      IntentRisk.writeSensitive => const Decision(
        DecisionOutcome.askConfirmation,
      ),
    };
  }

  /// The first doubt of [kinds] present in the proposal, in the order of [kinds].
  DoubtKind? _firstOf(List<DoubtKind> kinds, CommandProposal proposal) {
    for (final DoubtKind kind in kinds) {
      if (proposal.hasDoubt(kind)) {
        return kind;
      }
    }
    return null;
  }
}
