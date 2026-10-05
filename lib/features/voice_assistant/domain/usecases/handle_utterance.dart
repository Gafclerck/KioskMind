import '../dialog/dialog_manager.dart';
import '../entities/clarification_slot.dart';
import '../entities/command_proposal.dart';
import '../entities/decision_outcome.dart';
import '../entities/doubt.dart';
import '../entities/slot.dart';
import '../entities/voice_lexicon.dart';
import '../ports/intent_parser.dart';
import '../services/answer_application.dart';
import '../services/answer_reading.dart';
import '../services/command_validator.dart';
import '../services/decision_policy.dart';
import '../services/text_normalizer.dart';
import 'execute_command.dart';

/// What one utterance did to the session.
///
/// A turn is the whole of it: what was understood, what was decided, and what ran.
/// It is returned rather than kept in a field because a caller reads it to speak
/// and to draw, and because a test asserts it without touching the session that
/// produced it.
final class VoiceTurn {
  const VoiceTurn({
    required this.proposal,
    required this.decision,
    required this.execution,
    this.secondaryExecutions = const <CommandExecution>[],
  });

  /// The utterance as it was decided, after the answer completed it.
  final CommandProposal proposal;

  final Decision decision;

  /// What the handler answered, or null when the turn asked or refused rather than
  /// ran.
  final CommandExecution? execution;

  /// Subsequent executions when the turn carried a batch of commands (multi-action support).
  final List<CommandExecution> secondaryExecutions;

  /// Whether a handler ran and accepted the command.
  bool get executed => execution?.isExecuted ?? false;

  @override
  String toString() => 'VoiceTurn($decision, executed: $executed)';
}

/// Turns one utterance into what happens.
///
/// The whole pipeline in one place, in the order the contract fixes: a parser
/// understands the words, the validator adds what the catalog contradicts, the
/// policy decides, and only a decision that executes reaches a handler. Each step
/// is a port or a service, so a test replaces one of them without touching the
/// others, and nothing here knows about a widget, a device or a clock.
///
/// What makes it a dialogue rather than a sequence of independent commands is the
/// pending question. When one stands, the next words are the answer: they are read
/// for the doubt that was asked and they complete the utterance it was asked
/// about, instead of starting a command out of "sucre". Everything the merchant
/// said before the question is kept, so answering never costs him a quantity he
/// already gave. An utterance that would have been a complete command is read as an
/// answer to the question instead, which is the conservative reading: it completes
/// what the merchant started rather than recording something he did not finish
/// saying.
final class HandleUtterance {
  const HandleUtterance({
    required this.parser,
    required this.validator,
    required this.policy,
    required this.executor,
    required this.dialog,
    required this.answers,
    required this.reading,
  });

  final IntentParser parser;
  final CommandValidator validator;
  final DecisionPolicy policy;
  final ExecuteCommand executor;
  final DialogManager dialog;
  final AnswerApplication answers;
  final AnswerReading reading;

  /// Reads [utterance] and does what the decision says.
  ///
  /// An answer is an utterance like any other and is read as one: the same
  /// normaliser, the same French numbers, the same product resolution. It is not
  /// given to the intent detector, which only accepts commands and would report
  /// "sucre" as out of domain.
  Future<VoiceTurn> run(String utterance) async {
    final PendingQuestion? waiting = dialog.pending;
    if (waiting == null || dialog.awaitsManualEntry) {
      return _decideAndAct(await _understood(utterance));
    }

    if (waiting.slot != ClarificationSlot.confirmed) {
      final NormalizedText normalized = reading.normalizer.normalize(utterance);
      if (normalized.tokens.length <= 2 &&
          normalized.tokens.any(kNegativeWords.contains)) {
        dialog.reset();
        return const VoiceTurn(
          proposal: CommandProposal(
            intentId: kNoIntent,
            slots: <Slot>[],
            doubts: <Doubt>[Doubt(kind: DoubtKind.outOfDomain)],
            origin: ProposalOrigin.rules,
          ),
          decision: Decision(
            DecisionOutcome.reject,
            reason: DoubtKind.outOfDomain,
          ),
          execution: null,
        );
      }
    }

    final CommandProposal asked =
        dialog.awaiting ?? await _understood(utterance);
    final Object? value = reading.read(
      utterance,
      asked: waiting.reason,
      slot: waiting.slot,
    );
    return _decideAndAct(
      answers.apply(asked, asked: waiting.reason, value: value),
    );
  }

  /// Completes the pending question with an answer already resolved.
  ///
  /// The spoken path goes through [run]. This one takes the value as it is, which
  /// is what a frozen test case and the offline demo hold: a case states its
  /// answers as values, so reading them out of speech would be testing the words
  /// twice. Both paths meet in [AnswerApplication] and in [_decideAndAct], so there
  /// is one implementation of the turn and not two that can drift apart.
  Future<VoiceTurn> applyAnswer({
    required DoubtKind asked,
    required Object? value,
  }) {
    final CommandProposal? pending = dialog.awaiting;
    if (pending == null) {
      return Future<VoiceTurn>.error(
        StateError('Reponse a une question qui n est plus en attente'),
      );
    }
    return _decideAndAct(answers.apply(pending, asked: asked, value: value));
  }

  /// Decides [proposal], records it in the session, and runs it when it may run.
  ///
  /// The session is told before the command runs: an execution closes the pending
  /// question and opens the undo window, and telling it afterwards would close the
  /// window the handler has just opened.
  Future<VoiceTurn> _decideAndAct(CommandProposal proposal) async {
    final Decision decision = policy.decide(proposal);
    if (decision.isQuestion) {
      dialog.ask(decision, proposal: proposal);
    } else {
      dialog.decide(decision);
    }
    final CommandExecution? execution = decision.executes
        ? await executor.run(decision: decision, proposal: proposal)
        : null;

    final List<CommandExecution> secondaryExecutions = <CommandExecution>[];
    if (decision.executes && proposal.nextProposals.isNotEmpty) {
      for (final CommandProposal next in proposal.nextProposals) {
        final Decision nextDecision = policy.decide(next);
        if (nextDecision.executes) {
          final CommandExecution nextExec = await executor.run(
            decision: nextDecision,
            proposal: next,
          );
          secondaryExecutions.add(nextExec);
        }
      }
    }

    return VoiceTurn(
      proposal: proposal,
      decision: decision,
      execution: execution,
      secondaryExecutions: secondaryExecutions,
    );
  }

  /// The proposal [utterance] reads to, doubts of the validator included.
  ///
  /// The two are kept apart so a test can state which raised a doubt, and the
  /// proposal the policy sees carries both, as it will in the app.
  Future<CommandProposal> _understood(String utterance) async {
    final CommandProposal parsed = await parser.parse(utterance);
    final List<Doubt> doubts = <Doubt>[...parsed.doubts];
    for (final Doubt doubt in validator.validate(parsed)) {
      if (!doubts.contains(doubt)) {
        doubts.add(doubt);
      }
    }
    if (doubts.length == parsed.doubts.length) {
      return parsed;
    }
    return CommandProposal(
      intentId: parsed.intentId,
      slots: parsed.slots,
      doubts: doubts,
      origin: parsed.origin,
      nextProposals: parsed.nextProposals,
    );
  }
}
