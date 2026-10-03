/// How the device speaks.
///
/// Four numbers and a language, all of them technical: what a recap sounds like
/// is a property of the phone's synthesiser, not of the shop, so they are declared
/// once as settings rather than tuned in each place a sentence is read.
final class TtsVoice {
  const TtsVoice({
    required this.locale,
    required this.rate,
    required this.pitch,
    required this.volume,
  });

  /// Language tag, as the synthesiser names it.
  final String locale;

  /// Speed, from the engine's own scale.
  final double rate;

  /// Tone, from the engine's own scale.
  final double pitch;

  final double volume;

  @override
  bool operator ==(Object other) =>
      other is TtsVoice &&
      other.locale == locale &&
      other.rate == rate &&
      other.pitch == pitch &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(locale, rate, pitch, volume);

  @override
  String toString() => 'TtsVoice($locale, rate: $rate)';
}

/// Speaks.
///
/// Two calls and no settings: the voice is configured once by the adapter, so the
/// caller never repeats a rate and never has to know whether the engine takes
/// 0.5 or 0.45 for a normal pace. A failure to speak is not reported: the words
/// are always on screen, which is what the contract asks for, so a silent device
/// costs the merchant nothing.
abstract interface class TtsPort {
  /// Reads [text] aloud, the future completing when the sentence is finished.
  Future<void> speak(String text);

  /// Stops whatever is being said, now.
  ///
  /// Called before the microphone opens every single time: a phone that talks over
  /// its own microphone hears the synthesis as an order.
  Future<void> stop();
}
