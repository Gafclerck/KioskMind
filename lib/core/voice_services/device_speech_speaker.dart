import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
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
/// In flutter_tts / Android TextToSpeech:
/// 0 means QUEUE_FLUSH (drops existing playback and starts new sentence).
/// 1 means QUEUE_ADD (appends to end of playback queue).
const int kTtsQueueFlush = 0;

/// The synthesiser of `flutter_tts`, seen through [DeviceSpeechSpeaker].
final class PluginDeviceSpeechSpeaker implements DeviceSpeechSpeaker {
  PluginDeviceSpeechSpeaker({FlutterTts? engine})
    : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;

  @override
  Future<bool> supports(String locale) async {
    final String baseLanguage = _extractBaseLanguage(locale);

    // 1. Try isLanguageAvailable directly
    try {
      final dynamic direct = await _engine.isLanguageAvailable(locale);
      if (direct == true || direct == 1) {
        return true;
      }
      if (baseLanguage != locale) {
        final dynamic baseAvailable = await _engine.isLanguageAvailable(
          baseLanguage,
        );
        if (baseAvailable == true || baseAvailable == 1) {
          return true;
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PluginDeviceSpeechSpeaker] isLanguageAvailable not supported or failed: $e',
        );
      }
    } catch (_) {
      // Ignore other exceptions and proceed to getLanguages check
    }

    // 2. Query getLanguages (works on Windows SAPI, iOS, and Android fallback)
    bool getLanguagesAttempted = false;
    try {
      final dynamic languages = await _engine.getLanguages;
      if (languages is List) {
        getLanguagesAttempted = true;
        if (languages.isNotEmpty) {
          return matchesLanguageList(
            languages,
            locale,
            baseLanguage,
          );
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PluginDeviceSpeechSpeaker] getLanguages failed: $e');
      }
    } catch (_) {
      // Fallback
    }

    // 3. On desktop platforms (Windows, Linux, macOS) where availability querying
    // may not be supported by native plugins and no languages could be queried,
    // allow configure() to attempt setting the language.
    if (!getLanguagesAttempted &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return true;
    }

    return false;
  }

  @override
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  }) async {
    try {
      await _engine.awaitSpeakCompletion(true);
    } catch (_) {
      // Ignored if unsupported on current platform
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _engine.setQueueMode(kTtsQueueFlush);
      } catch (_) {
        // Ignored if unsupported
      }
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _engine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        );
      } catch (_) {
        // Ignored if unsupported
      }
    }

    // Set language with fallback to base language
    final String baseLanguage = _extractBaseLanguage(locale);
    try {
      final dynamic res = await _engine.setLanguage(locale);
      if (res == 0 && baseLanguage != locale) {
        await _engine.setLanguage(baseLanguage);
      }
    } catch (_) {
      if (baseLanguage != locale) {
        try {
          await _engine.setLanguage(baseLanguage);
        } catch (_) {}
      }
    }

    try {
      await _engine.setSpeechRate(rate);
    } catch (_) {}

    try {
      await _engine.setPitch(pitch);
    } catch (_) {}

    try {
      await _engine.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> say(String text) async {
    await _engine.speak(text);
  }

  @override
  Future<void> stop() async {
    await _engine.stop();
  }

  static String _extractBaseLanguage(String locale) {
    final int separatorIndex = locale.indexOf(RegExp(r'[-_]'));
    if (separatorIndex > 0) {
      return locale.substring(0, separatorIndex).toLowerCase();
    }
    return locale.toLowerCase();
  }

  @visibleForTesting
  static bool matchesLanguageList(
    List<dynamic> languages,
    String locale,
    String baseLanguage,
  ) {
    final String normalizedTarget = locale.toLowerCase().replaceAll('_', '-');
    final String normalizedBase = baseLanguage.toLowerCase();

    for (final dynamic item in languages) {
      if (item is! String) continue;
      final String lang = item.toLowerCase().replaceAll('_', '-');
      if (lang == normalizedTarget ||
          lang == normalizedBase ||
          lang.startsWith('$normalizedBase-') ||
          lang.startsWith('${normalizedBase}_')) {
        return true;
      }
    }
    return false;
  }
}
