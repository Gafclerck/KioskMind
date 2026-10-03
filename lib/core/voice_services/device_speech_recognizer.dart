import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One result as the engine reports it.
///
/// The plugin's own result type carries alternates, confidence and a result type
/// enum; none of that is a fact about the words, and passing it on would tie
/// every caller to the plugin.
typedef DeviceWords = ({String words, bool isFinal});

/// An engine error, still in the engine's words.
///
/// Kept as a string on purpose: the adapter that knows the plugin's vocabulary is
/// the one that reads "error_permission" and names a fault. Everything downstream
/// sees [SpeechServiceError] and never a plugin message.
final class DeviceSpeechError {
  const DeviceSpeechError(this.message);

  final String message;
}

/// The calls a speech engine offers, and nothing else.
///
/// This is the seam the plugin sits behind. It exists so the part of the adapter
/// that carries the voice rules - which language, how long a pause ends a
/// sentence, what a refused permission means - is testable without a phone and
/// without the plugin, while the class that actually talks to the plugin stays a
/// pure translation.
abstract interface class DeviceSpeechRecognizer {
  /// Prepares the engine and reports what it refuses through [onError], which may
  /// fire after the call returns.
  Future<bool> initialize({
    required void Function(DeviceSpeechError error) onError,
  });

  /// Opens a session in [localeId], ending after [pauseFor] of silence or
  /// [listenFor] at the latest.
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required List<String> contextualPhrases,
    required void Function(DeviceWords words) onWords,
  });

  /// Ends the session and lets the engine send its final result.
  Future<void> stop();

  /// Ends the session with no final result.
  Future<void> cancel();
}

/// The engine of `speech_to_text`, seen through [DeviceSpeechRecognizer].
///
/// Every method here is a translation and nothing else: the vocabulary of the
/// shop and the language are decided by [PlatformSpeechRecognizer], not here.
final class PluginDeviceSpeechRecognizer implements DeviceSpeechRecognizer {
  PluginDeviceSpeechRecognizer({SpeechToText? engine})
    : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;

  @override
  Future<bool> initialize({
    required void Function(DeviceSpeechError error) onError,
  }) {
    return _engine.initialize(
      onError: (SpeechRecognitionError error) =>
          onError(DeviceSpeechError(error.errorMsg)),
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required List<String> contextualPhrases,
    required void Function(DeviceWords words) onWords,
  }) {
    return _engine.listen(
      onResult: (SpeechRecognitionResult result) =>
          onWords((words: result.recognizedWords, isFinal: result.finalResult)),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        pauseFor: pauseFor,
        listenFor: listenFor,
        contextualPhrases: contextualPhrases.isEmpty ? null : contextualPhrases,
      ),
    );
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() => _engine.cancel();
}
