/// What the spike needs from a speech recogniser, and nothing more.
///
/// The point of this port is that the harness can be driven by a fake on a
/// workstation: the thirty phrase pass, its failures and its summary are ordinary
/// logic, and logic that can only be exercised on a phone is logic nobody checks.
/// The shape is deliberately the one the production `SpeechRecognizerPort` will
/// take in step 1c, so the adapter survives the spike.
library;

/// Can the device recognise French at all, and with what.
final class SttReadiness {
  const SttReadiness({
    required this.available,
    required this.microphoneGranted,
    required this.localeIds,
    this.error,
  });

  /// Whether a recogniser answered the initialisation at all.
  final bool available;

  final bool microphoneGranted;

  /// Locales the system claims to support, as it reports them. A system may claim
  /// a locale it cannot do offline, which is precisely what the pass reveals.
  final List<String> localeIds;

  final String? error;

  bool get hasFrench =>
      localeIds.any((String id) => id.toLowerCase().startsWith('fr'));

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'available': available,
      'microphoneGranted': microphoneGranted,
      'localeIds': localeIds,
      if (error != null) 'error': error,
    };
  }
}

/// What one listen attempt produced.
final class SttOutcome {
  const SttOutcome({
    required this.transcript,
    required this.latency,
    this.error,
  });

  final String transcript;

  /// From the moment listening started to the final result.
  final Duration latency;

  /// Why nothing usable came back, when nothing usable came back.
  final String? error;

  bool get succeeded => error == null && transcript.trim().isNotEmpty;
}

abstract interface class SpikeStt {
  /// Asks the system whether it can listen, and with which locales.
  Future<SttReadiness> prepare();

  /// Listens once. Never throws: a failure is a measured result, not a crash,
  /// because "the phone refused" is one of the answers the spike is looking for.
  Future<SttOutcome> listenOnce({required String localeId});
}
