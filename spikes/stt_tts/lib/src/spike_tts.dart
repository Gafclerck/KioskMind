/// What the spike needs from a speech synthesiser.
///
/// The spike only asks one question of the TTS, and it is a question about
/// latency and availability, not about quality: a French voice that exists and
/// starts speaking quickly enough to keep a sale flowing. The production
/// `TtsPort` in step 1c will add interruption and the amount formatter, which is
/// why the amounts are not measured here.
library;

/// Whether a French voice exists, and how long it took to start speaking.
final class TtsReport {
  const TtsReport({
    required this.frenchVoices,
    required this.startLatency,
    this.error,
  });

  /// Language codes the engine reports as available, unfiltered: the spike records
  /// what the system claims so a missing French pack is visible as a fact.
  final List<String> frenchVoices;

  /// Time from the call to the first audible sound. Null when nothing was heard.
  final Duration? startLatency;

  final String? error;

  bool get hasFrench => frenchVoices.isNotEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'voices': frenchVoices,
      'hasFrench': hasFrench,
      if (startLatency != null) 'startLatencyMs': startLatency!.inMilliseconds,
      if (error != null) 'error': error,
    };
  }
}

abstract interface class SpikeTts {
  Future<List<String>> availableLanguages();

  /// Speaks once and reports how long the engine took to make a sound. Stops on
  /// its own at the end, so a spike run never leaves the phone talking.
  Future<TtsReport> speakOnce({required String language, required String text});
}
