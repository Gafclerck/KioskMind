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
///
/// The synthesiser gets no fallback: a recap read in a language the merchant did not
/// choose is worse than a recap he reads on screen. A device that has no voice for
/// this locale therefore stays silent, and says so rather than quietly doing nothing.
const String kDefaultSpeechLocale = 'fr-FR';

/// A merchant reading an order aloud pauses between products.
const Duration kDefaultSpeechPauseFor = Duration(seconds: 3);

/// Past this, the session is closed whatever was heard.
const Duration kDefaultSpeechListenFor = Duration(seconds: 12);

/// The normal pace of `flutter_tts`.
///
/// Not half speed: the plugin doubles the rate on Android so the two platforms
/// agree, and both end up at their engine's normal pace with this value. Android
/// receives 1.0 (TextToSpeech's normal), iOS receives
/// `AVSpeechUtteranceDefaultSpeechRate`, and the recap reads at the speed the
/// phone's own voice was built for rather than at an arbitrary fraction of it.
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

/// Engine start-up and audio route latency, paid before the first syllable.
///
/// Not the same as speaking: a synthesiser that has never been asked to speak
/// still has to bind its service and open an audio route, and on Android that
/// binding is the slowest part of the whole exchange.
const Duration kTtsEngineGrace = Duration(seconds: 10);

/// Milliseconds per character at a rate of 1.0, so about 12.5 characters a second.
///
/// Deliberately under the real figure - French synthesis runs nearer 15 to 19
/// characters a second - because the two ways of being wrong are not equal. A
/// deadline that fires early cuts a recap off mid-sentence, in front of a
/// merchant who is waiting for it; a deadline that fires late only delays a case
/// that is already broken.
const int kTtsMsPerCharAtUnitRate = 80;

/// Ceiling on the deadline, so an absurd sentence cannot park the session for
/// minutes on a kiosk nobody is watching any more.
const Duration kTtsMaxSpeakDeadline = Duration(seconds: 60);

/// How long an engine that did not answer is left alone before being asked again.
///
/// Chrome publishes its voice list after page load, and Android finishes
/// downloading a voice pack in the background. An engine that has merely not
/// answered yet must not be treated as an engine that cannot speak, or the first
/// question of the session silences it for good.
const Duration kTtsReprobeAfter = Duration(seconds: 30);
