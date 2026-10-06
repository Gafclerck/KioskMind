import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../../../../core/voice_services/speech_recognizer_port.dart';
import '../../../../core/voice_services/speech_service_error.dart';
import '../../../../core/voice_services/tts_port.dart';
import '../../di/voice_dependencies.dart';
import '../../domain/dialog/dialog_manager.dart';
import '../../domain/entities/clarification_slot.dart';
import '../../domain/entities/doubt.dart';
import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/fact_result.dart';
import '../../domain/entities/intent_result.dart';
import '../../domain/ports/message_formulator.dart';
import '../../domain/ports/product_catalog_reader.dart';
import '../../domain/usecases/execute_command.dart';
import '../../domain/usecases/handle_utterance.dart';
import 'voice_message.dart';
import 'voice_outcome.dart';
import 'voice_recap.dart';
import 'voice_session_state.dart';

/// The voice session of one container.
///
/// It is the only place that opens a microphone, reads a clock and speaks. What it
/// does not do is understand: words go to [HandleUtterance], and whatever comes
/// back becomes state, a message and a sentence for the speaker. Keeping it that
/// thin is what lets the whole dialogue be replayed in a test without a phone, and
/// what lets a widget test drive a microphone that does not exist.
///
/// Three rules it holds to, all of them from the contract:
///
///  * the microphone only opens because the merchant pressed it;
///  * speaking stops before listening starts, because a phone that hears its own
///    synthesiser hears an order;
///  * every state it enters can be left, by answering, by undoing or by asking for
///    the screens.
final class VoiceSessionController extends Notifier<VoiceSessionState> {
  Timer? _tick;
  bool _busy = false;
  bool _disposed = false;

  @override
  VoiceSessionState build() {
    _startTicking();
    ref.onDispose(_dispose);
    unawaited(_refreshTtsAvailability());
    return const VoiceSessionState();
  }

  /// Opens the microphone and waits for the merchant.
  ///
  /// The permission prompt may appear here and nowhere else. A refusal, or a
  /// device with no recogniser, ends the attempt in a message and a route to the
  /// screens rather than in a button that does nothing.
  Future<void> startListening() async {
    if (!state.canListen || _busy) {
      return;
    }
    _busy = true;
    try {
      await _stopSpeech();
      ref.read(voiceDialogProvider).touch();
      _set(
        state.copyWith(
          status: VoiceSessionStatus.preparing,
          lastHeard: '',
          fault: null,
        ),
      );
      final SpeechRecognizerPort recognizer = await ref.read(
        voiceRecognizerProvider.future,
      );
      final SpeechReadiness readiness = await recognizer.initialize();
      if (readiness != SpeechReadiness.ready) {
        _microphoneLost(SpeechServiceError(readinessFaultOf(readiness)));
        return;
      }
      _set(state.copyWith(status: VoiceSessionStatus.listening));
      await recognizer.listen(
        SpeechListener(onUtterance: _onUtterance, onFault: _microphoneLost),
      );
    } finally {
      _busy = false;
    }
  }

  /// Closes the microphone, letting the engine send what it heard.
  Future<void> stopListening() async {
    final SpeechRecognizerPort? recognizer = _recognizer();
    await recognizer?.stop();
    await recognizer?.cancel();
    await _stopSpeech();
    if (!_disposed && state.status == VoiceSessionStatus.listening) {
      _set(state.copyWith(status: VoiceSessionStatus.idle, lastHeard: ''));
    }
  }

  /// Hands [words] to the turn, as the microphone did.
  ///
  /// Public because the manual screens and the demo scenario have words to hand
  /// over too, and because a test that has to fake a microphone to say two words
  /// is testing the fake.
  Future<void> submit(String words) async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      _set(
        state.copyWith(status: VoiceSessionStatus.thinking, lastHeard: words),
      );
      await _recognizer()?.stop();
      await _recognizer()?.cancel();
      final VoiceTurn turn = await ref
          .read(voiceHandleUtteranceProvider.future)
          .then((HandleUtterance handle) => handle.run(words));
      await _afterTurn(turn, userUtterance: words);
    } finally {
      _busy = false;
    }
  }

  /// Answers the pending question with [value], as a tap does.
  ///
  /// A tap is an answer the merchant gave with his finger rather than his voice,
  /// and it takes the same road as a spoken one: [HandleUtterance.applyAnswer] and
  /// then the same decision, so the two cannot drift apart.
  Future<void> answer({
    required DoubtKind asked,
    required Object? value,
  }) async {
    if (_busy || ref.read(voiceDialogProvider).pending == null) {
      return;
    }
    _busy = true;
    try {
      await _stopSpeech();
      _set(state.copyWith(status: VoiceSessionStatus.thinking));
      final VoiceTurn turn = await ref
          .read(voiceHandleUtteranceProvider.future)
          .then(
            (HandleUtterance handle) =>
                handle.applyAnswer(asked: asked, value: value),
          );
      await _afterTurn(turn);
    } finally {
      _busy = false;
    }
  }

  /// Answers the pending confirmation, positively or not.
  ///
  /// A no is a real answer: it settles nothing and leaves the module asking, which
  /// is what stops a sale the merchant did not agree to.
  Future<void> confirm(DoubtKind asked, {required bool accepted}) {
    return answer(asked: asked, value: accepted);
  }

  /// Takes back the sale of the undo window.
  Future<void> undo() async {
    if (!state.canUndo || _busy) {
      return;
    }
    _busy = true;
    try {
      await _stopSpeech();
      final Result<CancelLastSaleResult> result = await ref
          .read(voiceUndoLastCommandProvider.future)
          .then((undo) => undo.run());
      _afterUndo(result);
    } finally {
      _busy = false;
    }
  }

  /// Reads [text] aloud, then leaves the microphone free.
  ///
  /// The session is "speaking" for as long as the engine takes, which is what
  /// keeps the microphone closed while it talks.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    final TtsPort tts = ref.read(voiceTtsProvider);
    _set(state.copyWith(status: VoiceSessionStatus.speaking));
    try {
      await tts.speak(text);
    } finally {
      _set(state.copyWith(status: VoiceSessionStatus.idle));
    }
  }

  /// Opens the session again after the merchant asked for the screens.
  ///
  /// Also forgets the pending question: a session that timed out must not carry its
  /// half-understood command into the next one. Nothing is said: the merchant is
  /// coming back to the microphone, not to a sentence.
  void resume() {
    ref.read(voiceDialogProvider).reset();
    _set(
      state.copyWith(
        message: null,
        fault: null,
        lastHeard: '',
        awaitingManualEntry: false,
        status: VoiceSessionStatus.idle,
        undoSaleId: null,
        remainingUndo: Duration.zero,
      ),
    );
  }

  /// What a partial result changes: nothing but the transcript on screen.
  void _onUtterance(SpeechUtterance utterance) {
    if (state.status != VoiceSessionStatus.listening) {
      return;
    }
    if (!utterance.isFinal) {
      _set(state.copyWith(lastHeard: utterance.words));
      return;
    }
    unawaited(submit(utterance.words));
  }

  /// Turns a finished turn into what the panel shows and the speaker reads.
  Future<void> _afterTurn(VoiceTurn turn, {String userUtterance = ''}) async {
    final DialogManager dialog = ref.read(voiceDialogProvider);
    final PendingQuestion? pending = dialog.pending;
    VoiceMessage message;
    if (dialog.awaitsManualEntry) {
      message = const ManualEntryMessage();
    } else if (pending == null) {
      message = _messageOfRefusal(turn);
      if (message is DoneMessage) {
        try {
          final MessageFormulator formulator = ref.read(
            voiceMessageFormulatorProvider,
          );
          final List<FactResult> allFacts = <FactResult>[
            message.outcome.toFactResult(),
          ];
          for (final CommandExecution exec in turn.secondaryExecutions) {
            final VoiceOutcome? secondaryOutcome = outcomeOf(exec);
            if (secondaryOutcome != null) {
              allFacts.add(secondaryOutcome.toFactResult());
            }
          }

          final String naturalSpeech = formulator.formatSync(
            userUtterance: userUtterance,
            facts: allFacts,
            staticFallback: '',
          );
          if (naturalSpeech.isNotEmpty) {
            message = DoneMessage(
              message.outcome,
              customSpeechText: naturalSpeech,
            );
          }
        } catch (_) {
          // If formulation encounters any issue, retain standard DoneMessage
        }
      }
    } else {
      message = await _messageOfQuestion(turn, pending);
    }
    _set(
      state.copyWith(
        message: message,
        speechId: state.speechId + 1,
        status: VoiceSessionStatus.idle,
        lastHeard: '',
        awaitingManualEntry: dialog.awaitsManualEntry,
        undoSaleId: dialog.undoSaleId,
        remainingUndo: dialog.remainingUndo,
      ),
    );
  }

  /// What the session says when nothing is pending any more.
  VoiceMessage _messageOfRefusal(VoiceTurn turn) {
    final CommandExecution? execution = turn.execution;
    final VoiceOutcome? outcome = execution == null
        ? null
        : outcomeOf(execution);
    if (outcome != null) {
      return DoneMessage(outcome);
    }
    if (execution?.isExecuted ?? false) {
      return const UndoFailedMessage();
    }
    final DoubtKind? doubt = turn.decision.reason;
    return doubt == null
        ? const RefusalMessage(DoubtKind.outOfDomain)
        : RefusalMessage(doubt);
  }

  /// The question the session is now waiting on, and what it already knows.
  ///
  /// A confirmation carries the recap of the command it is about: the merchant is
  /// asked to authorise a product creation or a price change, and agreeing to a
  /// transcript is not agreeing to either. The recap is read from the proposal the
  /// session kept, so it names the command the same way whether the confirmation
  /// was reached by speech or by a tap.
  ///
  /// It reads the catalog for the name of a product the utterance gave as an
  /// identifier, which is why this is asynchronous. A name the catalog cannot
  /// supply leaves the recap without that line rather than showing the identifier.
  Future<VoiceMessage> _messageOfQuestion(
    VoiceTurn turn,
    PendingQuestion pending,
  ) async {
    final ClarificationSlot? slot = pending.slot;
    final DoubtKind doubt = pending.reason;
    if (slot == null) {
      return RefusalMessage(doubt);
    }
    return QuestionMessage(
      doubt: doubt,
      slot: slot,
      candidates: turn.proposal.doubtOf(doubt)?.candidates ?? const [],
      recap: await _recapOf(turn.proposal),
    );
  }

  /// The recap of [proposal], or null when it names nothing to authorise.
  Future<VoiceRecap?> _recapOf(CommandProposal proposal) async {
    try {
      final ProductCatalogReader catalog = await ref.read(
        voiceCatalogReaderProvider.future,
      );
      final VoiceRecap? recap = await pendingRecapOf(
        proposal,
        catalog.findById,
      );
      return (recap != null && recap.hasContent) ? recap : null;
    } catch (_) {
      // The catalog is what turns an identifier into a name. Without it the
      // confirmation still stands and the transcript is still there to read, so a
      // recap is an addition here and never the reason a question is lost.
      return null;
    }
  }

  void _afterUndo(Result<CancelLastSaleResult> result) {
    final DialogManager dialog = ref.read(voiceDialogProvider);
    final VoiceMessage message = switch (result) {
      Success<CancelLastSaleResult>(value: final CancelLastSaleResult value) =>
        UndoneMessage(
          SaleCancelled(<VoiceRecapLine>[
            for (final SaleLineResult line in value.restored)
              (
                name: line.name,
                qty: line.qty,
                unit: line.unit,
                unitPrice: line.appliedUnitPrice,
              ),
          ]),
        ),
      Failed<CancelLastSaleResult>(failure: const NothingToUndo()) =>
        const NothingToUndoMessage(),
      Failed<CancelLastSaleResult>() => const UndoFailedMessage(),
    };
    _set(
      state.copyWith(
        message: message,
        speechId: state.speechId + 1,
        status: VoiceSessionStatus.idle,
        lastHeard: '',
        undoSaleId: dialog.undoSaleId,
        remainingUndo: dialog.remainingUndo,
      ),
    );
  }

  /// The microphone is unusable: say why and offer the screens.
  void _microphoneLost(SpeechServiceError fault) {
    final DialogManager dialog = ref.read(voiceDialogProvider);
    if (!fault.isTerminal && dialog.pending != null) {
      _set(state.copyWith(status: VoiceSessionStatus.idle, lastHeard: ''));
      return;
    }
    dialog.reset();
    _set(
      state.copyWith(
        message: MicUnavailableMessage(fault.fault),
        speechId: state.speechId + 1,
        fault: fault,
        lastHeard: '',
        status: VoiceSessionStatus.idle,
        awaitingManualEntry: true,
        undoSaleId: null,
        remainingUndo: Duration.zero,
      ),
    );
  }

  /// Whether a device cannot hear the merchant, said as a fault.
  static SpeechFault readinessFaultOf(SpeechReadiness readiness) {
    return switch (readiness) {
      SpeechReadiness.ready => SpeechFault.unavailable,
      SpeechReadiness.permissionDenied => SpeechFault.permissionDenied,
      SpeechReadiness.unsupported => SpeechFault.unsupported,
      SpeechReadiness.unavailable => SpeechFault.unavailable,
    };
  }

  /// Asks the synthesiser what it can do, so the panel can explain a silence.
  ///
  /// Nothing blocks on it: the sheet must appear at once, and the verdict arrives
  /// a moment later. A synthesiser that cannot be reached leaves the field alone,
  /// because `unknown` shows nothing and the next probe may do better.
  Future<void> _refreshTtsAvailability() async {
    try {
      final TtsPort tts = ref.read(voiceTtsProvider);
      final TtsAvailability availability = await tts.availability();
      if (_disposed || state.ttsAvailability == availability) {
        return;
      }
      _set(state.copyWith(ttsAvailability: availability));
    } catch (_) {
      // The engine did not answer. The ticker keeps asking until it does.
    }
  }

  /// Silences the module before the microphone opens.
  Future<void> _stopSpeech() async {
    if (_disposed) {
      return;
    }
    try {
      await ref.read(voiceTtsProvider).stop();
    } catch (_) {
      // Le conteneur peut être en cours de fermeture.
    }
    await _recognizer()?.cancel();
  }

  SpeechRecognizerPort? _recognizer() {
    if (_disposed) {
      return null;
    }
    try {
      return ref.read(voiceRecognizerProvider).valueOrNull;
    } catch (_) {
      return null;
    }
  }

  void _set(VoiceSessionState next) {
    if (_disposed) {
      return;
    }
    state = next;
  }

  /// Keeps the countdown and the timeouts moving, as only a timer can.
  void _startTicking() {
    _tick ??= Timer.periodic(kSessionTickInterval, (Timer _) => _refresh());
  }

  /// The container is gone with the screen that owned it, so nothing is written
  /// any more: a timer outliving its notifier would touch a state nobody reads.
  void _dispose() {
    _disposed = true;
    _tick?.cancel();
    _tick = null;
  }

  /// Reads the deadlines against the clock and updates what the panel shows.
  ///
  /// A question that timed out and an undo window that closed both end here rather
  /// than in a callback nobody registered: the session already knows how to
  /// compute them, so there is one answer to the question and not two.
  void _refresh() {
    if (_disposed) {
      return;
    }
    // An engine that had not answered may have become reachable since (Chrome
    // publishes its voices after load, Android finishes a download in the
    // background), so the panel keeps re-asking while the verdict is that one.
    // The port answers from its cache until the verdict has aged, so this is a
    // read, not a conversation with the engine.
    if (state.ttsAvailability == TtsAvailability.engineUnreachable) {
      unawaited(_refreshTtsAvailability());
    }
    final DialogManager dialog = ref.read(voiceDialogProvider);
    if (dialog.awaitsManualEntry != state.awaitingManualEntry) {
      _set(
        state.copyWith(
          awaitingManualEntry: dialog.awaitsManualEntry,
          message: dialog.awaitsManualEntry
              ? const ManualEntryMessage()
              : state.message,
          speechId: dialog.awaitsManualEntry
              ? state.speechId + 1
              : state.speechId,
          undoSaleId: dialog.undoSaleId,
          remainingUndo: dialog.remainingUndo,
        ),
      );
      return;
    }
    final String? undoable = dialog.undoSaleId;
    if (undoable != state.undoSaleId ||
        dialog.remainingUndo != state.remainingUndo) {
      _set(
        state.copyWith(
          undoSaleId: undoable,
          remainingUndo: dialog.remainingUndo,
        ),
      );
    }
  }
}

/// The session of this container.
///
/// One container is one session: the pending question, the undo window and the
/// merchant on the other side of the microphone all belong together, and a second
/// container is a second till.
final NotifierProvider<VoiceSessionController, VoiceSessionState>
voiceSessionProvider =
    NotifierProvider<VoiceSessionController, VoiceSessionState>(
      VoiceSessionController.new,
    );
