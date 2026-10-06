import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kiosk_mind/core/voice_services/device_speech_speaker.dart';

/// Test engine that records calls and stubs return values for FlutterTts.
class StubFlutterTts extends FlutterTts {
  dynamic Function(String language)? onIsLanguageAvailable;
  dynamic Function()? onGetLanguages;
  dynamic Function(String language)? onSetLanguage;
  dynamic Function(double rate)? onSetSpeechRate;
  dynamic Function(double pitch)? onSetPitch;
  dynamic Function(double volume)? onSetVolume;
  dynamic Function(bool awaitCompletion)? onAwaitSpeakCompletion;
  dynamic Function(int queueMode)? onSetQueueMode;
  dynamic Function(String text)? onSpeak;
  dynamic Function()? onStop;

  final List<String> configuredLanguages = <String>[];
  final List<int> setQueueModes = <int>[];
  final List<String> spokenTexts = <String>[];
  int stopCalls = 0;

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (onIsLanguageAvailable != null) {
      return onIsLanguageAvailable!(language);
    }
    return false;
  }

  @override
  Future<dynamic> get getLanguages async {
    if (onGetLanguages != null) {
      return onGetLanguages!();
    }
    return <String>[];
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    configuredLanguages.add(language);
    if (onSetLanguage != null) {
      return onSetLanguage!(language);
    }
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    return onSetSpeechRate?.call(rate) ?? 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    return onSetPitch?.call(pitch) ?? 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    return onSetVolume?.call(volume) ?? 1;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    return onAwaitSpeakCompletion?.call(awaitCompletion) ?? 1;
  }

  @override
  Future<dynamic> setQueueMode(int queueMode) async {
    setQueueModes.add(queueMode);
    return onSetQueueMode?.call(queueMode) ?? 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    return onSpeak?.call(text) ?? 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCalls++;
    return onStop?.call() ?? 1;
  }

  /// Raises an engine error as the plugin does through its callback.
  void raiseError(dynamic message) => errorHandler?.call(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PluginDeviceSpeechSpeaker', () {
    test(
      'probe says available when the exact locale is available as boolean',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => lang == 'fr-FR';
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe says available when the exact locale is available as int 1',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => lang == 'fr-FR' ? 1 : 0;
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe falls back to base language fr when fr-FR is missing',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => lang == 'fr';
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe queries getLanguages when isLanguageAvailable throws PlatformException',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) =>
            throw PlatformException(code: 'not_implemented');
        engine.onGetLanguages = () => <String>['en-US', 'fr-FR', 'es-ES'];
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe matches underscored language codes like fr_FR from getLanguages',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => false;
        engine.onGetLanguages = () => <String>['en_US', 'fr_FR'];
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe matches prefix language codes like fr-CA from getLanguages',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => false;
        engine.onGetLanguages = () => <String>['en-US', 'fr-CA'];
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.available);
      },
    );

    test(
      'probe says localeUnavailable when no French variant is in the list',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => false;
        engine.onGetLanguages = () => <String>['en-US', 'de-DE', 'es-ES'];
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.localeUnavailable);
      },
    );

    test(
      'probe says engineUnreachable when the engine has nothing to say',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onIsLanguageAvailable = (String lang) => false;
        engine.onGetLanguages = () => <String>[];
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        final TtsProbe result = await speaker.probe('fr-FR');
        expect(result, TtsProbe.engineUnreachable);
      },
    );

    test('say reports a sentence the engine dropped', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onSpeak = (String text) => 0;
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
        engine: engine,
      );

      final bool spoken = await speaker.say('Bonjour le marchand');

      expect(spoken, isFalse);
      expect(engine.spokenTexts, <String>['Bonjour le marchand']);
    });

    test('say reports an engine error instead of waiting forever', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onSpeak = (String text) =>
          Future<dynamic>.delayed(const Duration(hours: 1), () => 1);
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
        engine: engine,
      );

      final Future<bool> spoken = speaker.say('Bonjour le marchand');
      engine.raiseError('error from TextToSpeech');

      expect(await spoken, isFalse);
    });

    test('say reports a sentence that was spoken', () async {
      final StubFlutterTts engine = StubFlutterTts();
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
        engine: engine,
      );

      final bool spoken = await speaker.say('Bonjour le marchand');

      expect(spoken, isTrue);
      expect(engine.spokenTexts, <String>['Bonjour le marchand']);
    });

    test(
      'matchesLanguageList handles normalized tags and prefixes correctly',
      () {
        expect(
          PluginDeviceSpeechSpeaker.matchesLanguageList(
            <String>['en-US', 'fr-FR'],
            'fr-FR',
            'fr',
          ),
          isTrue,
        );
        expect(
          PluginDeviceSpeechSpeaker.matchesLanguageList(
            <String>['en-US', 'fr_FR'],
            'fr-FR',
            'fr',
          ),
          isTrue,
        );
        expect(
          PluginDeviceSpeechSpeaker.matchesLanguageList(
            <String>['en-US', 'fr'],
            'fr-FR',
            'fr',
          ),
          isTrue,
        );
        expect(
          PluginDeviceSpeechSpeaker.matchesLanguageList(
            <String>['en-US', 'de-DE'],
            'fr-FR',
            'fr',
          ),
          isFalse,
        );
      },
    );

    test(
      'configure falls back to base language if exact locale returns 0',
      () async {
        final StubFlutterTts engine = StubFlutterTts();
        engine.onSetLanguage = (String lang) => lang == 'fr-FR' ? 0 : 1;
        final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
          engine: engine,
        );

        await speaker.configure(
          locale: 'fr-FR',
          rate: 0.5,
          pitch: 1.0,
          volume: 1.0,
        );

        expect(engine.configuredLanguages, <String>['fr-FR', 'fr']);
      },
    );

    test('say and stop delegate directly to engine', () async {
      final StubFlutterTts engine = StubFlutterTts();
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(
        engine: engine,
      );

      await speaker.say('Bonjour le marchand');
      expect(engine.spokenTexts, <String>['Bonjour le marchand']);

      await speaker.stop();
      expect(engine.stopCalls, 1);
    });
  });
}
