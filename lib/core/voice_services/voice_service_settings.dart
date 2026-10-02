import 'tts_port.dart';

/// Technical settings of the two device services.
///
/// They live here rather than in `VoiceConfig` because they describe the phone
/// and not the shop: the tunables of the pipeline are business facts a merchant
/// may want to change, and these are the ones a French recogniser needs whatever
/// he sells. Everything has a named default, and a test states the value it
/// depends on instead of repeating a literal.
final class VoiceServiceSettings {
  const VoiceServiceSettings({
    this.sttLocaleId = kDefaultSpeechLocale,
    this.sttPauseFor = kDefaultSpeechPauseFor,
    this.sttListenFor = kDefaultSpeechListenFor,
    this.ttsVoice = kDefaultTtsVoice,
    this.vocabularyLimit = kDefaultVocabularyLimit,
  });

  /// Language tag the recogniser and the synthesiser work in.
  ///
  /// Explicit rather than the system locale: a kiosk whose phone is set to
  /// another language must still understand its merchant, and a wrong locale is
  /// the first cause of a transcript nobody can route.
  final String sttLocaleId;

  /// Silence that ends what the merchant said.
  ///
  /// Long enough for a merchant who pauses mid-thought and short enough that the
  /// microphone does not stay open in a shop.
  final Duration sttPauseFor;

  /// Hard limit of one listening session.
  ///
  /// The session is closed by the merchant pressing the microphone again, so this
  /// is the backstop for a microphone left listening rather than a policy.
  final Duration sttListenFor;

  /// How the device speaks.
  final TtsVoice ttsVoice;

  /// How many words of the shop's vocabulary are offered to the recogniser.
  ///
  /// The words are a bias, not a grammar, and the engines that accept them ignore
  /// a long list; the limit keeps the payload small and the behaviour predictable.
  final int vocabularyLimit;
}

/// French is the language the module speaks, on both sides.
const String kDefaultSpeechLocale = 'fr-FR';

/// A merchant reading an order aloud pauses between products.
const Duration kDefaultSpeechPauseFor = Duration(seconds: 3);

/// Past this, the session is closed whatever was heard.
const Duration kDefaultSpeechListenFor = Duration(seconds: 12);

/// Half speed, the pace a recap is understood at in a noisy shop.
const double kDefaultTtsRate = 0.5;

const double kDefaultTtsPitch = 1;

const double kDefaultTtsVolume = 1;

const TtsVoice kDefaultTtsVoice = TtsVoice(
  locale: kDefaultSpeechLocale,
  rate: kDefaultTtsRate,
  pitch: kDefaultTtsPitch,
  volume: kDefaultTtsVolume,
);

const int kDefaultVocabularyLimit = 40;
