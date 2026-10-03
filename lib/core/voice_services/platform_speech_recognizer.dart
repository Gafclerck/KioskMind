import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:speech_to_text/speech_to_text.dart'
    show ListenFailedException, SpeechToTextNotInitializedException;

import 'device_speech_recognizer.dart';
import 'speech_recognizer_port.dart';
import 'speech_service_error.dart';
import 'voice_service_settings.dart';

/// What the engines call a refused microphone.
///
/// The plugins disagree on the spelling, which is exactly why this vocabulary is
/// read in one place and nowhere else.
const Set<String> kPermissionErrorMessages = <String>{
  'error_permission',
  'permission_denied',
  'permission',
};

/// The microphone of the device, behind the port the module uses.
///
/// Three responsibilities, all of them about the phone: say whether hearing is
/// possible, open and close a session, and turn whatever the engine threw or
/// reported into a [SpeechServiceError]. It never decides what was said and never
/// picks an intent.
///
/// The shop's vocabulary comes from the constructor rather than from each session:
/// it is a property of the shop, and passing it per call would let two sessions of
/// the same shop recognise French differently.
final class PlatformSpeechRecognizer implements SpeechRecognizerPort {
  PlatformSpeechRecognizer({
    required this.device,
    required this.settings,
    List<String> vocabulary = const <String>[],
  }) : _vocabulary = vocabulary.take(settings.vocabularyLimit).toList();

  /// The engine of the device, injected so the rules below can be tested without
  /// one.
  final DeviceSpeechRecognizer device;

  final VoiceServiceSettings settings;
  final List<String> _vocabulary;

  /// The session in progress, when there is one.
  SpeechListener? _listener;

  /// Words the recogniser is biased toward, as the adapter was configured.
  List<String> get vocabulary => List<String>.unmodifiable(_vocabulary);

  @override
  Future<SpeechReadiness> initialize() async {
    try {
      final bool ready = await device.initialize(onError: _engineFailed);
      return ready ? SpeechReadiness.ready : SpeechReadiness.unsupported;
    } on PlatformException {
      return SpeechReadiness.unavailable;
    }
  }

  @override
  Future<void> listen(SpeechListener listener) async {
    _listener = listener;
    try {
      await device.listen(
        localeId: settings.sttLocaleId,
        pauseFor: settings.sttPauseFor,
        listenFor: settings.sttListenFor,
        contextualPhrases: _vocabulary,
        onWords: (DeviceWords words) => listener.onUtterance(
          SpeechUtterance(words.words, isFinal: words.isFinal),
        ),
      );
    } on PlatformException catch (error) {
      _listener = null;
      listener.onFault(SpeechServiceError(faultOf(error.code)));
    } on ListenFailedException catch (error) {
      _listener = null;
      listener.onFault(
        SpeechServiceError(SpeechFault.listenFailed, detail: error.message),
      );
    } on SpeechToTextNotInitializedException {
      _listener = null;
      listener.onFault(const SpeechServiceError(SpeechFault.unavailable));
    }
  }

  @override
  Future<void> stop() async {
    _listener = null;
    await _guarded(device.stop);
  }

  @override
  Future<void> cancel() async {
    _listener = null;
    await _guarded(device.cancel);
  }

  /// An error the engine reported on its own, outside any call of ours.
  ///
  /// On Android this is how a refused permission arrives: several calls after the
  /// prompt, while the session is open. It is delivered to the session in progress
  /// so a refusal the merchant never hears about does not leave a microphone that
  /// silently stopped working.
  void _engineFailed(DeviceSpeechError error) {
    _listener?.onFault(SpeechServiceError(faultOf(error.message)));
  }

  /// The fault an engine failure means, named the same way whatever it said.
  static SpeechFault faultOf(String message) {
    return kPermissionErrorMessages.contains(message)
        ? SpeechFault.permissionDenied
        : SpeechFault.listenFailed;
  }

  /// Closing a microphone that was never opened is not a failure worth reporting
  /// to a merchant, so nothing leaves this adapter on those calls.
  Future<void> _guarded(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      return;
    }
  }
}
