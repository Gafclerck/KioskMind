import '../../../../core/voice_services/speech_service_error.dart';
import 'voice_message.dart';

/// What the microphone is doing right now.
///
/// Kept as four states and not as a bool "listening": the panel shows a different
/// face for each, and a merchant who pressed the button and heard nothing must be
/// able to see that the module is preparing rather than ignoring him.
enum VoiceSessionStatus {
  /// Nothing is happening: the merchant can speak or press the microphone.
  idle,

  /// The microphone is being opened.
  preparing,

  /// The microphone is open and the session is waiting for words.
  listening,

  /// Words were heard and are being routed.
  thinking,

  /// The module is speaking. The microphone stays closed until it stops.
  speaking,
}

/// Everything the session shows and nothing it decides.
///
/// One immutable value, read by the widgets and written only by the controller, so
/// a widget can never put the session in a state the controller would not put it
/// in. Nothing here is a word of text: the merchant's language is the
/// presentation layer's business, and this state carries the facts that text is
/// made of.
final class VoiceSessionState {
  const VoiceSessionState({
    this.status = VoiceSessionStatus.idle,
    this.lastHeard = '',
    this.message,
    this.speechId = 0,
    this.undoSaleId,
    this.remainingUndo = Duration.zero,
    this.awaitingManualEntry = false,
    this.fault,
  });

  final VoiceSessionStatus status;

  /// What the recogniser heard, partial included, so the transcript is readable
  /// while the merchant is still talking.
  final String lastHeard;

  /// What the session has to say, or null when it has nothing to say yet.
  final VoiceMessage? message;

  /// Bumped every time a new [message] is set.
  ///
  /// The speaker needs to know that a message changed rather than that the state
  /// did: the undo countdown changes the state several times a second, and reading
  /// a new sentence on every tick would make the module talk over itself.
  final int speechId;

  /// The sale the undo banner points at, or null when there is none.
  final String? undoSaleId;

  /// Time left to undo, zero when there is nothing to undo.
  final Duration remainingUndo;

  /// The session gave up on voice and the merchant goes to the screens.
  final bool awaitingManualEntry;

  /// The device failure that ended the voice attempt, kept so the panel can say
  /// why it ended.
  final SpeechServiceError? fault;

  /// The banner has something to undo.
  bool get canUndo =>
      undoSaleId != null &&
      remainingUndo > Duration.zero &&
      !awaitingManualEntry;

  /// The microphone may be pressed.
  bool get canListen =>
      !awaitingManualEntry &&
      (status == VoiceSessionStatus.idle ||
          status == VoiceSessionStatus.listening);

  /// Something is being listened to, prepared, routed or spoken.
  bool get isBusy =>
      status != VoiceSessionStatus.idle &&
      status != VoiceSessionStatus.listening;

  /// The undo banner is showing and the merchant may dismiss it.
  bool get showsBanner => canUndo || awaitingManualEntry;

  /// A copy with the given fields replaced.
  ///
  /// [message] and [fault] are nullable and a null means "no value", which a
  /// parameter cannot express, so a sentinel stands for "leave as is".
  VoiceSessionState copyWith({
    VoiceSessionStatus? status,
    String? lastHeard,
    Object? message = _kept,
    int? speechId,
    Object? undoSaleId = _kept,
    Object? remainingUndo = _kept,
    bool? awaitingManualEntry,
    Object? fault = _kept,
  }) {
    return VoiceSessionState(
      status: status ?? this.status,
      lastHeard: lastHeard ?? this.lastHeard,
      message: _kept == message ? this.message : message as VoiceMessage?,
      speechId: speechId ?? this.speechId,
      undoSaleId: _kept == undoSaleId ? this.undoSaleId : undoSaleId as String?,
      remainingUndo: _kept == remainingUndo
          ? this.remainingUndo
          : remainingUndo as Duration,
      awaitingManualEntry: awaitingManualEntry ?? this.awaitingManualEntry,
      fault: _kept == fault ? this.fault : fault as SpeechServiceError?,
    );
  }
}

/// Stands for a field the caller did not mention.
const Object _kept = Object();

/// A cadence, not a tunable: it decides how often the panel redraws while the undo
/// window counts down, and no shop and no test changes it.
const Duration kSessionTickInterval = Duration(milliseconds: 500);
