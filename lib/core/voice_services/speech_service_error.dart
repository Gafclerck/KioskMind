/// Why a device service could not do what was asked of it.
///
/// A fault is a fact about the phone, not about a command: the microphone is
/// closed, the language pack is missing, the engine gave up. It carries no
/// utterance and no merchant data, so it can be logged, displayed and mapped to
/// a message without any redaction.
enum SpeechFault {
  /// The merchant refused the microphone permission, or it was already refused.
  permissionDenied,

  /// The device has no usable recogniser for the configured language.
  unsupported,

  /// The microphone could not be opened at all.
  unavailable,

  /// The session failed while listening. The words may be partly heard.
  listenFailed,

  /// The device cannot speak the configured language.
  synthesisUnavailable,
}

/// A device failure, already translated from whatever the engine threw.
///
/// The translation happens in the adapter: no plugin exception and no `dynamic`
/// crosses a port, so a caller reads a named fault and decides what to do about
/// it instead of reading an exception type it cannot name.
final class SpeechServiceError {
  const SpeechServiceError(this.fault, {this.detail});

  const SpeechServiceError.permissionDenied()
    : this(SpeechFault.permissionDenied);

  final SpeechFault fault;

  /// What the engine said, kept for the technical report and never shown to the
  /// merchant as is.
  final String? detail;

  /// Whether the microphone may still work after this fault.
  ///
  /// A refused permission is the one fault that cannot be retried into success
  /// from inside the app, so it is the one that ends the voice attempt and opens
  /// the manual route.
  bool get isTerminal => fault == SpeechFault.permissionDenied;

  @override
  String toString() =>
      'SpeechServiceError(${fault.name}${detail == null ? '' : ': $detail'})';
}
