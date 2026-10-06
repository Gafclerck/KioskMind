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

/// What the device can do with the shop's language.
///
/// Three questions, not one, because they lead to three different behaviours.
/// "No voice for French" is a fact about the phone that no retry will change,
/// while "the engine has not answered" is a moment that has probably already
/// passed by the time the merchant asks again. Collapsing both into a boolean is
/// what makes a synthesiser that was merely not ready look permanently broken.
enum TtsAvailability {
  /// Nobody has asked yet.
  unknown,

  /// The shop's language can be read aloud.
  ready,

  /// The engine works and has no voice for the shop's language. Nothing will
  /// change without installing one.
  localeUnavailable,

  /// The engine did not answer. Worth asking again.
  engineUnreachable,
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
  ///
  /// Completes when the engine says it is done, or when the wait is judged
  /// exhausted. It never throws and never hangs: a synthesiser that swallows its
  /// own promise would otherwise leave the microphone closed for the rest of the
  /// session, which costs the merchant the voice rather than only the recap.
  Future<void> speak(String text);

  /// Stops whatever is being said, now.
  ///
  /// Called before the microphone opens every single time: a phone that talks over
  /// its own microphone hears the synthesis as an order.
  Future<void> stop();

  /// What the engine can currently do, for a merchant who hears nothing.
  ///
  /// Re-readable and idempotent. Exposed because silence with no explanation is
  /// indistinguishable from a bug from where the merchant sits.
  Future<TtsAvailability> availability();
}
