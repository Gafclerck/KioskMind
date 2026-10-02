import 'doubt.dart';

/// What the decision policy concluded about one proposal.
///
/// The five values are the whole vocabulary of the module: from a parsed
/// utterance to an action there is no other outcome, and the presentation layer
/// has nothing to invent. The codes are the ones written in
/// `voice/golden/text_cases.json`, so a case states the issue it expects with the
/// exact word the policy produces.
enum DecisionOutcome {
  execute('EXECUTE'),
  executeWithUndo('EXECUTE_WITH_UNDO'),
  askClarification('ASK_CLARIFICATION'),
  askConfirmation('ASK_CONFIRMATION'),
  reject('REJECT');

  const DecisionOutcome(this.code);

  final String code;

  /// The handler is called straight away, with the proposal as it stands.
  ///
  /// [askConfirmation] is not here even though it eventually calls the same
  /// handler: it calls it only once the merchant has answered, so the executor
  /// must be told to hold the command rather than to run it.
  bool get runsNow =>
      this == DecisionOutcome.execute ||
      this == DecisionOutcome.executeWithUndo;

  /// The merchant is being asked something and the session waits for an answer.
  bool get asksSomething =>
      this == DecisionOutcome.askClarification ||
      this == DecisionOutcome.askConfirmation;
}

/// The issue, and what produced it.
///
/// [reason] is the doubt that decided, kept so the recap and the spoken message
/// can name the problem instead of repeating "I did not understand". It is null
/// when nothing was doubtful, which is exactly the case that executes.
final class Decision {
  const Decision(this.outcome, {this.reason});

  final DecisionOutcome outcome;

  /// The doubt that drove the issue, or null when the proposal was clean.
  final DoubtKind? reason;

  /// The proposal was understood well enough to run, with an undo window for a
  /// write.
  bool get executes =>
      outcome == DecisionOutcome.execute ||
      outcome == DecisionOutcome.executeWithUndo;

  /// A question was asked, so the dialog holds a pending turn.
  bool get isQuestion => outcome.asksSomething;

  @override
  String toString() =>
      'Decision(${outcome.code}${reason == null ? '' : ', ${reason!.name}'})';
}
