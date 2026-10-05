import '../entities/clarification_slot.dart';
import '../entities/command_proposal.dart';
import '../entities/decision_outcome.dart';
import '../entities/doubt.dart';
import '../entities/slot.dart';
import '../entities/voice_config.dart';
import '../ports/voice_clock.dart';

/// What the session is doing right now.
enum VoiceDialogState {
  /// Nothing pending: the merchant can speak a new command.
  idle,

  /// A slot is missing and the session waits for the merchant to say it.
  waitingForAnswer,

  /// The recap was spoken and the session waits for a yes or a no.
  waitingForConfirmation,

  /// Nobody said anything for [VoiceConfig.sessionTimeout].
  expired,
}

/// One question the session is waiting on.
///
/// [slot] is null when no slot would be filled by the answer, as for a reference
/// the session cannot resolve. The merchant is still asked to say it again, so the
/// session stays in a question rather than guessing.
typedef PendingQuestion = ({ClarificationSlot? slot, DoubtKind reason});

/// The session state machine.
///
/// It holds what the merchant has already been asked and what has already run,
/// and the utterance a question is about, and nothing else: no handler, no widget,
/// no decision of its own. The policy decides, this remembers, the executor acts.
/// Keeping the three apart is what lets the same decision be replayed in a test
/// without a session and lets the same session be asserted without a policy.
///
/// It keeps that utterance because an answer is spoken as a new utterance and must
/// complete the previous one: "sucre" carries no quantity, and the two the merchant
/// said before the question are what turn it into a line. Storing the proposal here
/// rather than in the caller is what makes that the case in the app and not only in
/// the tests that keep the whole dialogue in one call.
///
/// Three invariants hold at every step, and each one exists because the merchant
/// can always get out:
///
///  * every wait has a deadline, and reaching it offers the manual screens
///    ([VoiceConfig.questionTimeout]);
///  * a command draws at most [VoiceConfig.maxClarificationTurns] questions, then
///    the same manual offer;
///  * a session that stops being fed expires rather than staying open.
final class DialogManager {
  DialogManager({required this.config, required this.clock});

  final VoiceConfig config;
  final VoiceClock clock;

  PendingQuestion? _pending;
  CommandProposal? _awaiting;
  VoiceDialogState _state = VoiceDialogState.idle;
  DateTime? _lastActivity;
  DateTime? _askedAt;
  DateTime? _undoDeadline;
  String? _undoSaleId;
  int _turns = 0;
  bool _manualEntry = false;

  /// What the session is doing, computed against the clock.
  ///
  /// Reading the state rather than storing it means a test that moves the clock
  /// sees the deadline pass without waiting for a timer, and the application
  /// cannot forget to tick. A session nobody has spoken into yet is idle: it has
  /// nothing to expire, and reporting otherwise would greet the merchant with an
  /// expired session before the first word.
  VoiceDialogState get state {
    if (_sessionExpired) {
      return VoiceDialogState.expired;
    }
    if (_questionExpired) {
      return VoiceDialogState.idle;
    }
    return _state;
  }

  PendingQuestion? get pending {
    final VoiceDialogState current = state;
    if (current == VoiceDialogState.idle ||
        current == VoiceDialogState.expired) {
      return null;
    }
    return _pending;
  }

  /// The utterance the pending question was asked about.
  ///
  /// Null whenever no question stands, so a caller completing an answer never has
  /// to check the two states separately: a question that timed out has no utterance
  /// left to complete.
  CommandProposal? get awaiting => pending == null ? null : _awaiting;

  /// Clarification turns already spent on this command. A confirmation does not
  /// count: the merchant is not being asked to name anything.
  int get turns => _turns;

  /// The session gave up on voice and the merchant goes to the screens.
  ///
  /// A question that timed out counts as giving up: the module asked something and
  /// heard nothing, so it stops asking and offers the screens, which is the same
  /// offer the turn limit makes.
  bool get awaitsManualEntry => _manualEntry || _questionExpired;

  /// The sale the undo banner points at, or null when there is none.
  String? get undoSaleId {
    final DateTime? deadline = _undoDeadline;
    if (deadline == null || clock.now().isBefore(deadline)) {
      return deadline == null ? null : _undoSaleId;
    }
    return null;
  }

  /// Time left to undo, zero when there is nothing to undo.
  Duration get remainingUndo {
    final DateTime? deadline = _undoDeadline;
    if (deadline == null) {
      return Duration.zero;
    }
    final Duration left = deadline.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Records what the policy decided about a command that asks nothing.
  ///
  /// An execution closes the pending question and renews the session; a refusal
  /// closes it too. A question must go through [ask], so the turn limit and the
  /// deadline cannot be skipped by calling this with one.
  void decide(Decision decision) {
    _resetPending();
    _touch();
    if (_manualEntry) {
      return;
    }
    if (decision.executes) {
      _turns = 0;
      return;
    }
    if (decision.outcome == DecisionOutcome.askConfirmation) {
      _ask(ClarificationSlot.confirmed, decision.reason);
    }
  }

  /// Records that the session is waiting for the merchant to say something.
  ///
  /// Past the turn limit this does not ask: it offers the manual screens instead,
  /// which is the only exit a state is allowed to have. [proposal] is the utterance
  /// the question is about, kept so the answer can complete it; which addressing
  /// the question uses follows from that utterance rather than from a second fact
  /// the caller would have to keep in step, so a stock question never waits for a
  /// line that does not exist.
  void ask(Decision decision, {required CommandProposal proposal}) {
    if (!decision.isQuestion) {
      return;
    }
    final DoubtKind? reason = decision.reason;
    if (reason == null && decision.outcome != DecisionOutcome.askConfirmation) {
      return;
    }
    final DoubtKind effectiveReason = reason ?? DoubtKind.amountMismatch;
    _touch();
    _closeUndoWindow();
    if (_turns >= config.maxClarificationTurns) {
      _offerManualEntry();
      return;
    }
    _awaiting = proposal;
    if (decision.outcome == DecisionOutcome.askConfirmation) {
      _ask(ClarificationSlot.confirmed, effectiveReason);
      return;
    }
    _turns += 1;
    _ask(
      ClarificationSlot.forDoubt(
        effectiveReason,
        hasItems: _hasItems(proposal),
      ),
      effectiveReason,
    );
  }

  /// Opens the undo window on the sale a write just produced.
  ///
  /// Closing the window on a new question is deliberate: a merchant saying
  /// "annule" while the module is still asking which product it meant must not
  /// cancel the previous sale.
  void registerUndo(String saleId) {
    _undoSaleId = saleId;
    _undoDeadline = clock.now().add(config.undoWindow);
    _touch();
  }

  /// Consumes the undo window and returns what it pointed at.
  String? takeUndoable() {
    final String? saleId = undoSaleId;
    _undoDeadline = null;
    _undoSaleId = null;
    return saleId;
  }

  /// Closes the session and forgets it. The next utterance starts a new one.
  void reset() {
    _pending = null;
    _awaiting = null;
    _state = VoiceDialogState.idle;
    _askedAt = null;
    _turns = 0;
    _manualEntry = false;
    _closeUndoWindow();
    _lastActivity = null;
  }

  void _ask(ClarificationSlot? slot, DoubtKind? reason) {
    final DoubtKind kind = reason ?? DoubtKind.outOfDomain;
    _pending = (slot: slot, reason: kind);
    _askedAt = clock.now();
    _state = slot == ClarificationSlot.confirmed
        ? VoiceDialogState.waitingForConfirmation
        : VoiceDialogState.waitingForAnswer;
  }

  void _resetPending() {
    _pending = null;
    _awaiting = null;
    _askedAt = null;
    _state = VoiceDialogState.idle;
  }

  /// Whether the utterance carries lines, which is what chooses the addressing of
  /// a product question.
  bool _hasItems(CommandProposal proposal) =>
      proposal.valueOf<List<ItemMention>>(kItemsSlot) != null;

  /// Leaving voice for the screens is terminal for this command: the merchant
  /// keeps the microphone off, so a stray word must not reopen the dialogue.
  void _offerManualEntry() {
    _resetPending();
    _manualEntry = true;
  }

  void _touch() => _lastActivity = clock.now();

  /// A session nobody has spoken into has not expired: it has not started.
  bool get _sessionExpired {
    final DateTime? last = _lastActivity;
    return last != null &&
        clock.now().difference(last) >= config.sessionTimeout;
  }

  /// Whether the pending question went past its deadline.
  bool get _questionExpired {
    final DateTime? asked = _askedAt;
    return asked != null &&
        clock.now().difference(asked) >= config.questionTimeout;
  }

  /// A question in progress takes precedence over the undo banner, so a merchant
  /// answering a question with "annule" cannot cancel the sale from before it.
  void _closeUndoWindow() {
    _undoDeadline = null;
    _undoSaleId = null;
  }
}
