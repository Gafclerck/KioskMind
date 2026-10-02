import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'spike_tts.dart';

/// Drives `flutter_tts` to answer one question: does a French voice exist, and how
/// long until the first sound.
///
/// The timing comes from the start handler, not the completion handler. An engine
/// can report an utterance finished in under a second while taking half of it to
/// make the first sound, and that half second is what a merchant feels when the
/// phone is supposed to be confirming a sale.
final class FlutterTtsProbe implements SpikeTts {
  FlutterTtsProbe({FlutterTts? engine}) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;

  static const Duration _speakDeadline = Duration(seconds: 15);

  @override
  Future<List<String>> availableLanguages() async {
    final Object? languages = await _engine.getLanguages;
    if (languages is! List<Object?>) {
      return <String>[];
    }
    return languages.cast<String>();
  }

  @override
  Future<TtsReport> speakOnce({
    required String language,
    required String text,
  }) async {
    final List<String> french = (await availableLanguages())
        .where((String code) => code.toLowerCase().startsWith('fr'))
        .toList();
    final Stopwatch stopwatch = Stopwatch()..start();
    final Completer<Duration> started = Completer<Duration>();

    try {
      await _engine.setLanguage(language);
      await _engine.setSpeechRate(0.5);
      await _engine.awaitSpeakCompletion(true);
      _engine.setStartHandler(() {
        if (!started.isCompleted) {
          started.complete(stopwatch.elapsed);
        }
      });
      await _engine.speak(text);
      return TtsReport(
        frenchVoices: french,
        startLatency: await started.future.timeout(_speakDeadline),
      );
    } on Object catch (error) {
      return TtsReport(
        frenchVoices: french,
        startLatency: null,
        error: error.toString(),
      );
    } finally {
      await _engine.stop();
    }
  }
}
