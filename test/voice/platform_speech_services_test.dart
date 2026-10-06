import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/voice_services/device_speech_recognizer.dart';
import 'package:kiosk_mind/core/voice_services/device_speech_speaker.dart';
import 'package:kiosk_mind/core/voice_services/platform_speech_recognizer.dart';
import 'package:kiosk_mind/core/voice_services/platform_tts.dart';
import 'package:kiosk_mind/core/voice_services/speech_recognizer_port.dart';
import 'package:kiosk_mind/core/voice_services/speech_service_error.dart';
import 'package:kiosk_mind/core/voice_services/tts_port.dart';
import 'package:kiosk_mind/core/voice_services/voice_service_settings.dart';
import 'package:speech_to_text/speech_to_text.dart'
    show ListenFailedException, SpeechToTextNotInitializedException;

/// An engine that answers what a test tells it to.
///
/// The adapters carry the rules the merchant feels - which language, what the
/// shop's vocabulary is, what a refused permission means - and an engine is the
/// only boundary behind them, so faking it is what makes those rules reachable
/// without a phone.
class FakeDeviceRecognizer implements DeviceSpeechRecognizer {
  FakeDeviceRecognizer({this.ready = true});

  /// What [initialize] answers.
  bool ready;

  /// Thrown by the next [initialize], for a device that is not there at all.
  Object? initializeFailure;

  /// Thrown by the next [listen].
  Object? listenFailure;

  void Function(DeviceSpeechError error)? initializeErrorCallback;
  void Function(DeviceWords words)? wordsCallback;

  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  String? localeId;
  Duration? pauseFor;
  Duration? listenFor;
  List<String> contextualPhrases = <String>[];

  @override
  Future<bool> initialize({
    required void Function(DeviceSpeechError error) onError,
  }) async {
    initializeErrorCallback = onError;
    final Object? failure = initializeFailure;
    if (failure != null) {
      throw failure;
    }
    return ready;
  }

  @override
  Future<void> listen({
    required String localeId,
    required Duration pauseFor,
    required Duration listenFor,
    required List<String> contextualPhrases,
    required void Function(DeviceWords words) onWords,
  }) async {
    listenCount++;
    final Object? failure = listenFailure;
    if (failure != null) {
      throw failure;
    }
    this.localeId = localeId;
    this.pauseFor = pauseFor;
    this.listenFor = listenFor;
    this.contextualPhrases = contextualPhrases;
    wordsCallback = onWords;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  /// The engine reports words, as it does from the platform channel.
  void hear(String words, {bool isFinal = false}) =>
      wordsCallback?.call((words: words, isFinal: isFinal));

  /// The engine reports a failure of its own, outside any call of ours.
  void reportError(String message) =>
      initializeErrorCallback?.call(DeviceSpeechError(message));
}

/// A synthesiser that remembers instead of speaking.
class FakeDeviceSpeaker implements DeviceSpeechSpeaker {
  FakeDeviceSpeaker({this.canSpeak = true});

  /// Whether the shop's language is available to the engine.
  bool canSpeak;

  /// When set, [probe] answers this instead of [canSpeak].
  TtsProbe? probeOverride;

  Object? probeFailure;
  Object? sayFailure;
  Object? stopFailure;

  /// When set, [say] reports the sentence dropped rather than spoken.
  bool dropped = false;

  /// While true, every [say] waits for a [stop] before answering, like a real
  /// engine that swallows its own completion promise. The platform's own `stop`
  /// before a sentence releases the previous one the same way it releases this
  /// one.
  bool hangSays = false;

  /// The sentences [hangSays] is holding: each is released by the next [stop].
  final List<Completer<void>> _pending = <Completer<void>>[];

  int configureCount = 0;
  int probeCount = 0;
  int sayCount = 0;
  int stopCount = 0;

  String? locale;
  double? rate;
  double? pitch;
  double? volume;

  String? said;

  @override
  Future<TtsProbe> probe(String locale) async {
    probeCount++;
    final Object? failure = probeFailure;
    if (failure != null) {
      throw failure;
    }
    return probeOverride ??
        (canSpeak ? TtsProbe.available : TtsProbe.localeUnavailable);
  }

  @override
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  }) async {
    configureCount++;
    this.locale = locale;
    this.rate = rate;
    this.pitch = pitch;
    this.volume = volume;
  }

  @override
  Future<bool> say(String text) async {
    sayCount++;
    said = text;
    if (dropped) {
      return false;
    }
    final Object? failure = sayFailure;
    if (failure != null) {
      throw failure;
    }
    if (hangSays) {
      final Completer<void> gate = Completer<void>();
      _pending.add(gate);
      await gate.future;
    }
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    final Object? failure = stopFailure;
    if (failure != null) {
      throw failure;
    }
    final List<Completer<void>> pending = List<Completer<void>>.of(_pending);
    _pending.clear();
    for (final Completer<void> gate in pending) {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }
}

PlatformSpeechRecognizer recognizerOver(
  FakeDeviceRecognizer device, {
  VoiceServiceSettings settings = const VoiceServiceSettings(),
  List<String> vocabulary = const <String>[],
}) {
  return PlatformSpeechRecognizer(
    device: device,
    settings: settings,
    vocabulary: vocabulary,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the microphone adapter', () {
    test('answers ready when the engine is there', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();

      expect(await recognizerOver(device).initialize(), SpeechReadiness.ready);
    });

    test('answers unsupported when the device has no recogniser', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer(ready: false);

      expect(
        await recognizerOver(device).initialize(),
        SpeechReadiness.unsupported,
      );
    });

    test('answers unavailable when the engine cannot be reached', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer()
        ..initializeFailure = PlatformException(code: 'no_engine');

      expect(
        await recognizerOver(device).initialize(),
        SpeechReadiness.unavailable,
      );
    });

    test('listens in French, for the shop, with its own pauses', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();
      final PlatformSpeechRecognizer recognizer = recognizerOver(
        device,
        vocabulary: <String>['sucre', 'savon'],
      );

      await recognizer.initialize();
      await recognizer.listen(
        const SpeechListener(onUtterance: _ignore, onFault: _ignoreFault),
      );

      expect(device.localeId, kDefaultSpeechLocale);
      expect(device.pauseFor, kDefaultSpeechPauseFor);
      expect(device.listenFor, kDefaultSpeechListenFor);
      expect(device.contextualPhrases, <String>['sucre', 'savon']);
    });

    test('caps the vocabulary it hands to the engine', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();
      final PlatformSpeechRecognizer recognizer = recognizerOver(
        device,
        settings: const VoiceServiceSettings(vocabularyLimit: 2),
        vocabulary: List<String>.generate(10, (int index) => 'mot$index'),
      );

      await recognizer.initialize();
      await recognizer.listen(
        const SpeechListener(onUtterance: _ignore, onFault: _ignoreFault),
      );

      expect(device.contextualPhrases, <String>['mot0', 'mot1']);
    });

    test('hands the words over, partial and final alike', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();
      final List<SpeechUtterance> heard = <SpeechUtterance>[];
      await recognizerOver(device).listen(
        SpeechListener(
          onUtterance: heard.add,
          onFault: (SpeechServiceError fault) {},
        ),
      );

      device.hear('vendu deux');
      device.hear('vendu deux savon', isFinal: true);

      expect(heard.map((SpeechUtterance u) => u.words), <String>[
        'vendu deux',
        'vendu deux savon',
      ]);
      expect(heard.map((SpeechUtterance u) => u.isFinal), <bool>[false, true]);
    });

    test('names a refused permission instead of throwing it', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer()
        ..listenFailure = PlatformException(code: 'error_permission');
      final List<SpeechServiceError> faults = <SpeechServiceError>[];

      await recognizerOver(device).listen(
        SpeechListener(
          onUtterance: (SpeechUtterance u) {},
          onFault: faults.add,
        ),
      );

      expect(faults.single.fault, SpeechFault.permissionDenied);
      expect(faults.single.isTerminal, isTrue);
    });

    test('reports an engine failure to the session in progress', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();
      final List<SpeechServiceError> faults = <SpeechServiceError>[];
      final PlatformSpeechRecognizer recognizer = recognizerOver(device);
      await recognizer.initialize();
      await recognizer.listen(
        SpeechListener(
          onUtterance: (SpeechUtterance u) {},
          onFault: faults.add,
        ),
      );

      device.reportError('permission_denied');

      expect(faults.single.fault, SpeechFault.permissionDenied);
    });

    test('names any other engine failure as a listening failure', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer();
      final List<SpeechServiceError> faults = <SpeechServiceError>[];
      final PlatformSpeechRecognizer recognizer = recognizerOver(device);
      await recognizer.initialize();
      await recognizer.listen(
        SpeechListener(
          onUtterance: (SpeechUtterance u) {},
          onFault: faults.add,
        ),
      );

      device.reportError('error_no_match');

      expect(faults.single.fault, SpeechFault.listenFailed);
    });

    test('names the plugin listen failure and keeps its reason', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer()
        ..listenFailure = ListenFailedException('busy');
      final List<SpeechServiceError> faults = <SpeechServiceError>[];

      await recognizerOver(device).listen(
        SpeechListener(
          onUtterance: (SpeechUtterance u) {},
          onFault: faults.add,
        ),
      );

      expect(faults.single.fault, SpeechFault.listenFailed);
      expect(faults.single.detail, 'busy');
    });

    test('names an engine that was never initialised', () async {
      final FakeDeviceRecognizer device = FakeDeviceRecognizer()
        ..listenFailure = SpeechToTextNotInitializedException();
      final List<SpeechServiceError> faults = <SpeechServiceError>[];

      await recognizerOver(device).listen(
        SpeechListener(
          onUtterance: (SpeechUtterance u) {},
          onFault: faults.add,
        ),
      );

      expect(faults.single.fault, SpeechFault.unavailable);
    });

    test(
      'closing a microphone that was never opened is not an error',
      () async {
        final FakeDeviceRecognizer device = FakeDeviceRecognizer();
        final PlatformSpeechRecognizer recognizer = recognizerOver(device);

        await recognizer.stop();
        await recognizer.cancel();

        expect(device.stopCount, 1);
        expect(device.cancelCount, 1);
      },
    );
  });

  group('the voice adapter', () {
    test('configures the engine once, with the settings', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker();
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');
      await tts.speak('et un savon');

      expect(device.configureCount, 1);
      expect(device.locale, kDefaultSpeechLocale);
      expect(device.rate, kDefaultTtsRate);
      expect(device.pitch, kDefaultTtsPitch);
      expect(device.volume, kDefaultTtsVolume);
      expect(device.sayCount, 2);
    });

    test('stays silent on a device that cannot speak French', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker(canSpeak: false);
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');

      expect(device.sayCount, 0);
      expect(device.configureCount, 0);
    });

    test('says nothing for an empty sentence', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker();
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('   ');

      expect(device.sayCount, 0);
    });

    test('never lets a device failure reach the session', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()
        ..probeFailure = PlatformException(code: 'no_tts');
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');
      await tts.stop();

      expect(device.sayCount, 0);
      expect(device.stopCount, 1);
    });

    test('never lets a failure while speaking reach the session', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()
        ..sayFailure = PlatformException(code: 'speak_failed');
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');

      expect(device.sayCount, 1);
    });

    test('stops what it is saying', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker();
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.stop();

      expect(device.stopCount, 1);
    });

    test('lets a failure while stopping reach nobody', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()
        ..stopFailure = PlatformException(code: 'stop_failed');
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.stop();

      expect(device.stopCount, 1);
    });

    test('stops the previous sentence before saying the next one', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker();
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('premiere');
      await tts.speak('deuxieme');

      expect(device.sayCount, 2);
      expect(device.stopCount, 2);
    });

    test('gives up on an engine that never answers', () {
      fakeAsync((FakeAsync async) {
        final FakeDeviceSpeaker device = FakeDeviceSpeaker()..hangSays = true;
        final PlatformTts tts = PlatformTts(
          device: device,
          settings: const VoiceServiceSettings(),
        );

        bool done = false;
        tts.speak('deux savons').then((_) {
          done = true;
        });

        async.elapse(const Duration(minutes: 2));

        expect(done, isTrue);
        // Once for the stop before the sentence, once to silence the engine that
        // went quiet for too long.
        expect(device.stopCount, 2);
      });
    });

    test('a longer sentence gets a longer deadline', () {
      fakeAsync((FakeAsync async) {
        final FakeDeviceSpeaker device = FakeDeviceSpeaker()..hangSays = true;
        final PlatformTts tts = PlatformTts(
          device: device,
          settings: const VoiceServiceSettings(),
        );

        bool done = false;
        // 'deux' is 4 characters: 10 s of grace plus 4 * 80 ms / 0.5 = 10.64 s.
        tts.speak('deux').then((_) {
          done = true;
        });

        async.elapse(const Duration(milliseconds: 10600));
        expect(done, isFalse, reason: 'still inside the deadline');

        async.elapse(const Duration(milliseconds: 100));
        expect(done, isTrue, reason: 'past the deadline, the session is freed');
      });
    });

    test('a sentence the engine dropped is not reported as spoken', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()..dropped = true;
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');

      expect(device.sayCount, 1);
    });

    test('a missing plugin never reaches the session', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()
        ..sayFailure = MissingPluginException('flutter_tts');
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');
      await tts.stop();

      expect(device.sayCount, 1);
      // Once for the stop before the sentence, once for the stop the test asks for.
      expect(device.stopCount, 2);
    });
  });

  group('the verdict', () {
    test('a device without French speaks nothing and is not retried', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker(canSpeak: false);
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
        now: () => DateTime(2026),
      );

      expect(await tts.availability(), TtsAvailability.localeUnavailable);
      await tts.speak('deux savons');
      expect(device.sayCount, 0);

      // The sans-pari is a fact about the device, not a moment: it is not asked
      // again, and no fallback language is tried.
      expect(await tts.availability(), TtsAvailability.localeUnavailable);
      expect(device.probeCount, 1);
    });

    test(
      'an engine that had not answered is asked again once it has aged',
      () async {
        DateTime now = DateTime(2026);
        final FakeDeviceSpeaker device = FakeDeviceSpeaker()
          ..probeOverride = TtsProbe.engineUnreachable;
        final PlatformTts tts = PlatformTts(
          device: device,
          settings: const VoiceServiceSettings(),
          now: () => now,
        );

        expect(await tts.availability(), TtsAvailability.engineUnreachable);
        expect(device.probeCount, 1);

        // The moment has not aged yet: the verdict stands.
        now = now.add(const Duration(seconds: 10));
        expect(await tts.availability(), TtsAvailability.engineUnreachable);
        expect(device.probeCount, 1);

        // Once it has aged, the engine - which answers now - is heard.
        device.probeOverride = TtsProbe.available;
        now = now.add(kTtsReprobeAfter);
        expect(await tts.availability(), TtsAvailability.ready);
        expect(device.probeCount, 2);
      },
    );

    test('a working device is reconfigured only once', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker();
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      await tts.speak('deux savons');
      await tts.speak('et un savon');

      expect(device.configureCount, 1);
      expect(device.probeCount, 1);
    });

    test(
      'parallel sentences are spoken one after the other, not over each other',
      () async {
        final FakeDeviceSpeaker device = FakeDeviceSpeaker();
        final PlatformTts tts = PlatformTts(
          device: device,
          settings: const VoiceServiceSettings(),
        );

        await Future.wait(<Future<void>>[
          tts.speak('premiere'),
          tts.speak('deuxieme'),
        ]);

        expect(device.sayCount, 2);
        expect(device.stopCount, 2);
      },
    );

    test('stop settles a stuck sentence and the one queued behind it', () async {
      final FakeDeviceSpeaker device = FakeDeviceSpeaker()..hangSays = true;
      final PlatformTts tts = PlatformTts(
        device: device,
        settings: const VoiceServiceSettings(),
      );

      bool firstDone = false;
      bool secondDone = false;
      tts.speak('premiere').then((_) {
        firstDone = true;
      });
      // Wait until the first sentence is actually being said, so its queue is a
      // real one and not an artifact of a preparation still running.
      while (device.sayCount < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      tts.speak('deuxieme').then((_) {
        secondDone = true;
      });
      expect(firstDone, isFalse);
      expect(secondDone, isFalse);

      await tts.stop();
      // The stop frees the chain; the sentences settle a microtask later.
      await Future<void>.delayed(Duration.zero);

      expect(
        firstDone,
        isTrue,
        reason: 'the sentence being said was interrupted',
      );
      expect(
        secondDone,
        isTrue,
        reason: 'the queued sentence was settled too, not left hanging',
      );
      expect(
        device.sayCount,
        1,
        reason: 'only the first sentence reached the engine before the stop',
      );
      expect(device.stopCount, greaterThanOrEqualTo(2));

      // The microphone opened and closed again: the next sentence is said like
      // the first one would have been, and the chain is usable again.
      device.hangSays = false;
      await tts.speak('troisieme');
      expect(device.sayCount, 2);
    });
  });

  group('what the two ports say about themselves', () {
    test('a partial result is not a final one', () {
      expect(const SpeechUtterance.partial('vendu deux').isFinal, isFalse);
      expect(const SpeechUtterance.final_('vendu deux').isFinal, isTrue);
      expect(const SpeechUtterance('vendu deux').isFinal, isFalse);
    });

    test('only a refused permission ends the voice attempt', () {
      const SpeechServiceError refused = SpeechServiceError.permissionDenied();
      expect(refused.isTerminal, isTrue);
      expect(
        const SpeechServiceError(SpeechFault.listenFailed).isTerminal,
        isFalse,
      );
      expect(refused.detail, isNull);
      expect(refused.toString(), contains('permissionDenied'));
    });

    test('two voices are the same when they sound the same', () {
      expect(kDefaultTtsVoice, kDefaultTtsVoice);
      expect(kDefaultTtsVoice.hashCode, kDefaultTtsVoice.hashCode);
      expect(
        kDefaultTtsVoice,
        isNot(
          const TtsVoice(
            locale: 'en-US',
            rate: kDefaultTtsRate,
            pitch: kDefaultTtsPitch,
            volume: kDefaultTtsVolume,
          ),
        ),
      );
      expect(kDefaultTtsVoice.toString(), contains(kDefaultSpeechLocale));
    });
  });
}

void _ignore(SpeechUtterance utterance) {}

void _ignoreFault(SpeechServiceError fault) {}
