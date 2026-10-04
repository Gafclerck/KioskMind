import 'speech_service_error.dart';

/// Whether the device can hear the merchant, and whether it is allowed to.
///
/// Readiness is asked once per press of the microphone and answered before any
/// listening happens, because the merchant is entitled to know why nothing is
/// being heard. The three refusals are kept apart on purpose: a missing language
/// pack is a device problem the merchant cannot solve, while a refused permission
/// is a choice he made and may make differently later.
enum SpeechReadiness {
  /// A recogniser exists, in the configured language, and the microphone is
  /// allowed.
  ready,

  /// The microphone could be used but the merchant refused it.
  permissionDenied,

  /// The device has no recogniser that can serve the configured language.
  unsupported,

  /// The recogniser could not be reached at all.
  unavailable,
}

/// What the recogniser believes it heard, possibly not the whole sentence yet.
///
/// A partial result is what makes the transcript readable on screen while the
/// merchant is still talking; only a final one is a command, because half a
/// quantity is a doubt and not a sale.
final class SpeechUtterance {
  const SpeechUtterance(this.words, {this.isFinal = false});

  const SpeechUtterance.partial(String words) : this(words);

  const SpeechUtterance.final_(String words) : this(words, isFinal: true);

  final String words;

  final bool isFinal;
}

/// Where a listening session reports what it hears.
///
/// Two callbacks and no stream: a session is opened and closed by the caller,
/// so its lifetime is the caller's business and not something a subscription has
/// to be kept alive across. Nothing here decides anything either - the caller is
/// the one that knows what a command is.
final class SpeechListener {
  const SpeechListener({required this.onUtterance, required this.onFault});

  /// Called for every result the engine produces, partial and final alike.
  final void Function(SpeechUtterance utterance) onUtterance;

  /// Called when the session fails. No further utterance will arrive, so the
  /// caller is expected to stop listening and say what happened.
  final void Function(SpeechServiceError fault) onFault;
}

/// Hears the merchant.
///
/// The port holds no voice logic: it knows about sessions, not about commands. It
/// is deliberately the smallest of the three device interfaces, so a fake in a
/// test is a few lines and a platform adapter is a translation of a plugin
/// without any behaviour of its own hiding in between.
abstract interface class SpeechRecognizerPort {
  /// Asks the platform for the microphone, once per session of the app.
  ///
  /// This is the only place a permission prompt may appear, and it appears only
  /// because the merchant pressed the microphone: nothing here runs on its own.
  Future<SpeechReadiness> initialize();

  /// Opens a listening session that reports to [listener] until [stop] or
  /// [cancel] is called.
  Future<void> listen(SpeechListener listener);

  /// Ends the session, letting the engine send its final result.
  Future<void> stop();

  /// Ends the session without any final result, for a turn the merchant
  /// abandoned.
  Future<void> cancel();
}
