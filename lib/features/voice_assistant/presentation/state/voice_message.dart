import '../../../../core/voice_services/speech_service_error.dart';
import '../../domain/entities/clarification_slot.dart';
import '../../domain/entities/doubt.dart';
import '../../domain/entities/product_snapshot.dart';
import 'voice_outcome.dart';

/// What the session has to say about the last turn.
///
/// Declared in terms of facts and never in terms of words: the merchant reads it
/// on screen and hears it spoken, and both must come from his language, so the
/// text is produced from this by the presentation layer and nowhere else. A class
/// per situation rather than one with a nullable field per situation, because the
/// situations are told apart by a pattern match and a missing field would be
/// silently empty rather than absent.
sealed class VoiceMessage {
  const VoiceMessage();
}

/// The session is waiting for an answer.
///
/// [candidates] is only filled for an ambiguous product: it is the only doubt that
/// can be settled by tapping, because it is the only one that already knows what
/// the merchant may have meant.
final class QuestionMessage extends VoiceMessage {
  const QuestionMessage({
    required this.doubt,
    required this.slot,
    this.candidates = const <ProductSnapshot>[],
  });

  final DoubtKind doubt;

  /// What the answer fills, as the frozen set names it.
  final ClarificationSlot slot;

  final List<ProductSnapshot> candidates;

  /// The question can be settled by a yes or a no rather than by naming
  /// something.
  bool get isYesOrNo =>
      slot == ClarificationSlot.confirmed || doubt.answersByYesOrNo;
}

/// The command was understood and refused, and naming something would not change
/// that.
final class RefusalMessage extends VoiceMessage {
  const RefusalMessage(this.doubt);

  final DoubtKind doubt;
}

/// The command ran, with what it did.
final class DoneMessage extends VoiceMessage {
  const DoneMessage(this.outcome, {this.customSpeechText});

  final VoiceOutcome outcome;

  /// Optional AI or natural formulated response overriding static concatenation.
  final String? customSpeechText;
}

/// The sale of the undo window was taken back.
final class UndoneMessage extends VoiceMessage {
  const UndoneMessage(this.outcome, {this.customSpeechText});

  final VoiceOutcome outcome;

  /// Optional AI or natural formulated response overriding static concatenation.
  final String? customSpeechText;
}

/// There was nothing to take back, which is an answer and not a failure.
final class NothingToUndoMessage extends VoiceMessage {
  const NothingToUndoMessage();
}

/// The cancellation handler refused, and the sale is still there.
final class UndoFailedMessage extends VoiceMessage {
  const UndoFailedMessage();
}

/// The microphone cannot be used, and voice stops here.
final class MicUnavailableMessage extends VoiceMessage {
  const MicUnavailableMessage(this.fault);

  final SpeechFault fault;
}

/// The session gave up on voice and hands the merchant to the screens.
///
/// Terminal until he asks for the microphone again: a stray word must not reopen a
/// dialogue he has left.
final class ManualEntryMessage extends VoiceMessage {
  const ManualEntryMessage();
}
