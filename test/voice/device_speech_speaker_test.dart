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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PluginDeviceSpeechSpeaker', () {
    test('supports returns true when direct locale is available as boolean', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => lang == 'fr-FR';
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports returns true when direct locale is available as int 1', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => lang == 'fr-FR' ? 1 : 0;
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports falls back to base language fr when fr-FR is missing', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => lang == 'fr';
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports queries getLanguages when isLanguageAvailable throws PlatformException', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => throw PlatformException(code: 'not_implemented');
      engine.onGetLanguages = () => <String>['en-US', 'fr-FR', 'es-ES'];
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports matches underscored language codes like fr_FR from getLanguages', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => false;
      engine.onGetLanguages = () => <String>['en_US', 'fr_FR'];
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports matches prefix language codes like fr-CA from getLanguages', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => false;
      engine.onGetLanguages = () => <String>['en-US', 'fr-CA'];
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isTrue);
    });

    test('supports returns false when no French variant is available in language list', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onIsLanguageAvailable = (String lang) => false;
      engine.onGetLanguages = () => <String>['en-US', 'de-DE', 'es-ES'];
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      final bool result = await speaker.supports('fr-FR');
      expect(result, isFalse);
    });

    test('matchesLanguageList handles normalized tags and prefixes correctly', () {
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
    });

    test('configure falls back to base language if exact locale returns 0', () async {
      final StubFlutterTts engine = StubFlutterTts();
      engine.onSetLanguage = (String lang) => lang == 'fr-FR' ? 0 : 1;
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      await speaker.configure(
        locale: 'fr-FR',
        rate: 0.5,
        pitch: 1.0,
        volume: 1.0,
      );

      expect(engine.configuredLanguages, <String>['fr-FR', 'fr']);
    });

    test('say and stop delegate directly to engine', () async {
      final StubFlutterTts engine = StubFlutterTts();
      final PluginDeviceSpeechSpeaker speaker = PluginDeviceSpeechSpeaker(engine: engine);

      await speaker.say('Bonjour le marchand');
      expect(engine.spokenTexts, <String>['Bonjour le marchand']);

      await speaker.stop();
      expect(engine.stopCalls, 1);
    });
  });
}
