import 'package:flutter_tts/flutter_tts.dart';

/// The calls a speech synthesiser offers, and nothing else.
///
/// The same seam as the recogniser, for the same reason: what the device can speak
/// and how it is configured is a question about the engine, and the rule that
/// matters - never queue a sentence on top of another - belongs to code that a
/// test can reach without a phone.
abstract interface class DeviceSpeechSpeaker {
  /// Whether [locale] can be spoken at all.
  Future<bool> supports(String locale);

  /// Configures the engine once per session of the app.
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  });

  /// Says [text] and waits for it to be finished.
  Future<void> say(String text);

  /// Stops the sentence in progress.
  Future<void> stop();
}

/// Queue mode that drops the sentence in progress instead of lining up behind it.
///
/// The module speaks one sentence at a time and never wants a recap repeated
/// because the merchant pressed the microphone, so the queue is flushed rather
/// than added to.
const int kTtsQueueFlush = 1;

/// The synthesiser of `flutter_tts`, seen through [DeviceSpeechSpeaker].
final class PluginDeviceSpeechSpeaker implements DeviceSpeechSpeaker {
  PluginDeviceSpeechSpeaker({FlutterTts? engine})
    : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;

  @override
  Future<bool> supports(String locale) async {
    return await _engine.isLanguageAvailable(locale) == true;
  }

  @override
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  }) async {
    // The completion flag is what lets the caller know it may open the
    // microphone: without it `speak` returns before a word was said.
    await _engine.awaitSpeakCompletion(true);
    await _engine.setQueueMode(kTtsQueueFlush);
    await _engine.setLanguage(locale);
    await _engine.setSpeechRate(rate);
    await _engine.setPitch(pitch);
    await _engine.setVolume(volume);
  }

  @override
  Future<void> say(String text) async {
    await _engine.speak(text);
  }

  @override
  Future<void> stop() async {
    await _engine.stop();
  }
}
