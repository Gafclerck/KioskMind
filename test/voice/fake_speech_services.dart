import 'dart:async';

import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/core/voice_services/speech_service_error.dart';
import 'package:kiosk_mind/core/voice_services/tts_port.dart';

/// A microphone that only does what a test tells it to.
///
/// The two device services are the boundaries of the module, and a boundary is
/// exactly what a test replaces: this fake takes the place of the phone, so the
/// session, the dialogue and the widgets can be exercised without one. It records
/// what it was asked for, because a test that cannot see whether the microphone
/// was opened proves nothing about the microphone.
class FakeSpeechRecognizer implements SpeechRecognizerPort {
  FakeSpeechRecognizer({this.readiness = SpeechReadiness.ready});

  /// What the next [initialize] answers.
  SpeechReadiness readiness;

  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  /// The session in progress, so a test can feed it words.
  SpeechListener? listener;

  @override
  Future<SpeechReadiness> initialize() async {
    initializeCount++;
    return readiness;
  }

  @override
  Future<void> listen(SpeechListener newListener) async {
    listenCount++;
    listener = newListener;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  /// The merchant is still talking.
  void hear(String words) => listener?.onUtterance(SpeechUtterance(words));

  /// The merchant finished a sentence.
  void hearFinal(String words) =>
      listener?.onUtterance(SpeechUtterance.final_(words));

  /// The engine gives up, as it does when the microphone is not allowed.
  void fail(SpeechServiceError fault) => listener?.onFault(fault);
}

/// A voice that remembers every sentence instead of saying it.
class FakeTts implements TtsPort {
  final List<String> spoken = <String>[];
  int stopCount = 0;

  /// When set, [speak] waits for it before saying anything.
  ///
  /// A synthesiser that answers instantly lets a test read nothing of the state the
  /// session is in while it talks, and "the microphone stays closed until the recap
  /// is finished" is exactly a claim about that state.
  Completer<void>? gate;

  @override
  Future<void> speak(String text) async {
    await gate?.future;
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  /// The last sentence, which is the one the panel reacts to.
  String get lastSpoken => spoken.isEmpty ? '' : spoken.last;
}
