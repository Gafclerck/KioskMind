import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_tts/flutter_tts.dart';

/// What a probe of the engine found.
///
/// Three answers rather than a boolean, because the caller reacts differently to
/// each: a working engine without the right voice needs no retry, while an engine
/// that did not answer has to be asked again.
enum TtsProbe {
  /// The locale can be spoken.
  available,

  /// The engine answered and does not have this locale. Definitive.
  localeUnavailable,

  /// The engine did not answer at all. Worth another try.
  engineUnreachable,
}

/// The calls a speech synthesiser offers, and nothing else.
///
/// The same seam as the recogniser, for the same reason: what the device can speak
/// and how it is configured is a question about the engine, and the rule that
/// matters - never queue a sentence on top of another - belongs to code that a
/// test can reach without a phone.
abstract interface class DeviceSpeechSpeaker {
  /// What the engine can currently do with [locale].
  Future<TtsProbe> probe(String locale);

  /// Configures the engine once per session of the app.
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  });

  /// Says [text] and waits for it to be finished.
  ///
  /// Whether the engine accepted it: an engine that dropped the sentence because
  /// the previous one was still playing, or that refused it outright, says false
  /// rather than pretending it spoke. A caller that cannot tell those apart will
  /// report a recap that was never heard.
  Future<bool> say(String text);

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
    : _engine = engine ?? FlutterTts() {
    _engine.setErrorHandler(_onEngineError);
  }

  final FlutterTts _engine;

  /// Completed when the engine reports a failure, so a [say] that would otherwise
  /// wait on an utterance the engine has already abandoned stops waiting.
  ///
  /// Held as a field rather than a local because the plugin raises errors through
  /// a callback it installed once, with no argument to say which call it belongs
  /// to. [say] claims it for the duration of the utterance.
  Completer<bool>? _failure;

  void _onEngineError(dynamic message) {
    if (kDebugMode) {
      debugPrint('[PluginDeviceSpeechSpeaker] engine error: $message');
    }
    final Completer<bool>? failure = _failure;
    if (failure != null && !failure.isCompleted) {
      failure.complete(false);
    }
  }

  @override
  Future<TtsProbe> probe(String locale) async {
    final String baseLanguage = _extractBaseLanguage(locale);

    // The direct answer decides it when it is positive.
    try {
      final dynamic direct = await _engine.isLanguageAvailable(locale);
      if (_isAffirmative(direct)) {
        return TtsProbe.available;
      }
      if (baseLanguage != locale) {
        final dynamic base = await _engine.isLanguageAvailable(baseLanguage);
        if (_isAffirmative(base)) {
          return TtsProbe.available;
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PluginDeviceSpeechSpeaker] isLanguageAvailable failed: $e',
        );
      }
    } catch (_) {
      // Some engines simply do not implement the question. The list below decides.
    }

    // The language list is what separates an engine that answered from one that
    // did not, which is the distinction the caller cannot recover on its own.
    //
    // An engine with nothing to say for itself has not told us it lacks the voice;
    // it has told us it is not there yet. Chrome publishes its voice list after
    // page load, and Android finishes downloading a voice pack in the background,
    // so an empty list means "ask again", not "this phone will never speak French".
    try {
      final dynamic languages = await _engine.getLanguages;
      if (languages is List && languages.isNotEmpty) {
        return matchesLanguageList(languages, locale, baseLanguage)
            ? TtsProbe.available
            : TtsProbe.localeUnavailable;
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PluginDeviceSpeechSpeaker] getLanguages failed: $e');
      }
    } catch (_) {
      // Falls through to the verdict below.
    }

    return TtsProbe.engineUnreachable;
  }

  @override
  Future<void> configure({
    required String locale,
    required double rate,
    required double pitch,
    required double volume,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Before awaitSpeakCompletion: the plugin only holds the call open for
      // completion when the queue mode is already QUEUE_FLUSH, and asking in the
      // other order leaves the first sentence completing on the second one's cue.
      await _guard(() => _engine.setQueueMode(kTtsQueueFlush));
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // The audio category and route the recap uses: playback so it is still
      // heard with the ringer switch off, which a shop needs; defaultToSpeaker so
      // it does not go to an earpiece that is not there. The session is never
      // activated by the plugin, only deactivated on completion, so the category
      // is all there is to set.
      await _guard(
        () => _engine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        ),
      );
    }

    // Not on iOS. There, the plugin keeps the result of a call in a single slot and
    // only hands it back from didFinish, which a stopSpeaking never reaches - so a
    // completion signal either resolves the wrong sentence or never resolves at
    // all. Better an immediate answer than a wrong or absent one.
    if (!(defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb)) {
      await _guard(() => _engine.awaitSpeakCompletion(true));
    }

    final String baseLanguage = _extractBaseLanguage(locale);
    try {
      // The exact tag first. An engine that says no to it (0) is asked for the
      // base language: 'fr' names every variant of it that a phone may only
      // know by its root, and a hypothesis confirmed by setLanguage is not
      // something the probe had to guess at.
      final dynamic accepted = await _engine.setLanguage(locale);
      if (!_isAffirmative(accepted) && baseLanguage != locale) {
        await _engine.setLanguage(baseLanguage);
      }
    } catch (_) {
      // Some engines refuse the tag outright, without the courtesy of a 0.
      if (baseLanguage != locale) {
        try {
          await _engine.setLanguage(baseLanguage);
        } catch (_) {
          // The engine does not want a language it can name: it will read with
          // its own default, which the shop's locale asks as close to as it can.
        }
      }
    }

    // A language tag is not a voice. iOS resolves AVSpeechSynthesisVoice against
    // an exact tag and hands back nil for anything else, and a nil voice means the
    // system default reads the recap in the wrong language. Asking for the voice
    // by identifier is what makes a fr-CA phone read French properly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _selectVoiceFor(locale, baseLanguage);
    }

    await _guard(() => _engine.setSpeechRate(rate));
    await _guard(() => _engine.setPitch(pitch));
    await _guard(() => _engine.setVolume(volume));
  }

  @override
  Future<bool> say(String text) async {
    final Completer<bool> failure = Completer<bool>();
    _failure = failure;
    try {
      final dynamic outcome = await Future.any<Object?>(<Future<Object?>>[
        _engine.speak(text),
        // A failure is not a return value: the plugin abandons the utterance
        // without ever answering the call that started it.
        failure.future.then<bool>((bool _) => false),
      ]);
      // A bool can only have come from the failure branch, and an engine that
      // dropped the sentence answers 0 on every platform that has such a code.
      // Web answers null once the utterance ends, which counts as spoken.
      return outcome is bool ? outcome : outcome != 0;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PluginDeviceSpeechSpeaker] speak failed: $e');
      }
      return false;
    } finally {
      if (identical(_failure, failure)) {
        _failure = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    await _guard(() => _engine.stop());
  }

  /// Picks the closest installed voice for the locale and asks for it by name.
  Future<void> _selectVoiceFor(String locale, String baseLanguage) async {
    try {
      final dynamic voices = await _engine.getVoices;
      if (voices is! List) {
        return;
      }
      for (final dynamic voice in voices) {
        if (voice is! Map) {
          continue;
        }
        final Object? identifier = voice['identifier'];
        final Object? voiceLocale = voice['locale'];
        if (identifier is! String || voiceLocale is! String) {
          continue;
        }
        final String normalized = voiceLocale.toLowerCase().replaceAll(
          '_',
          '-',
        );
        if (normalized == locale.toLowerCase() ||
            normalized == baseLanguage.toLowerCase() ||
            normalized.startsWith('${baseLanguage.toLowerCase()}-')) {
          await _guard(
            () => _engine.setVoice(<String, String>{
              'identifier': identifier,
              'locale': voiceLocale,
              'name': voice['name'] is String ? voice['name'] as String : '',
            }),
          );
          return;
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PluginDeviceSpeechSpeaker] getVoices failed: $e');
      }
    } catch (_) {
      // A phone with no matching voice keeps the language setting on its own.
    }
  }

  /// Runs a call the engine may not implement, and survives the refusal.
  ///
  /// Every method of this plugin is optional on at least one platform, and none of
  /// them failing is a reason for the merchant to lose the recap.
  static Future<void> _guard(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (_) {
      // The engine does not want to be configured. It will speak with its
      // defaults, which is better than not speaking.
    }
  }

  static bool _isAffirmative(dynamic value) => value == true || value == 1;

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
