import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import 'device_speech_speaker.dart';
import 'tts_port.dart';
import 'voice_service_settings.dart';

/// The synthesiser of the device, behind the port the module uses.
///
/// Three jobs: configure the engine once, keep a verdict that a later moment can
/// overturn, and never let a sentence survive the one that follows it. A device
/// that cannot speak is not an error the caller has to handle, because every
/// sentence spoken here is also on screen.
final class PlatformTts implements TtsPort {
  PlatformTts({
    required this.device,
    required this.settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The engine of the device, injected so the rules below can be tested without
  /// one.
  final DeviceSpeechSpeaker device;

  final VoiceServiceSettings settings;

  /// The clock the verdict ages against, injectable so a test can sit on either
  /// side of the re-probe delay without waiting for it.
  final DateTime Function() _now;

  /// The configuration, run once and remembered as a future rather than as a flag.
  ///
  /// A flag would be wrong twice over: a caller arriving while the first one is
  /// still configuring would skip straight to speaking on an engine that has no
  /// language yet, and a verdict reached by the first caller would be the verdict
  /// for the whole session even when it was only a guess made too early.
  Future<TtsAvailability>? _preparation;

  /// The verdict last reached about the shop's language.
  TtsAvailability _availability = TtsAvailability.unknown;

  /// When that verdict was reached, so a provisional one can be aged out.
  DateTime? _probedAt;

  /// The sentence in progress, completed when it ends or is given up on.
  ///
  /// A single slot on purpose. The contract is that a sentence never outlives the
  /// next one, and a queue would be the opposite of that.
  Completer<void>? _current;

  /// How many stops have been asked for, marking the sentences asked for before
  /// each of them. A sentence that was requested before a stop but still warming
  /// its engine when the stop landed must not be spoken afterwards: the stop is
  /// the microphone opening, and a recap finishing on top of it would be heard
  /// as an order.
  int _stopEpoch = 0;

  /// What the engine can do, re-probing a verdict that has aged.
  ///
  /// A device without the voice is a fact and is not asked again. An engine that
  /// had not answered is a moment, and is asked again once [kTtsReprobeAfter] has
  /// passed - Chrome publishes its voice list after page load, and Android
  /// finishes downloading a voice pack in the background, so a verdict reached on
  /// the first question of the session should not silence the rest of it.
  ///
  /// A verdict that has never been reached is shared, not raced: two sentences
  /// asking at the same time get the same probe and the same configuration,
  /// because an engine is configured once, not once per caller.
  @override
  Future<TtsAvailability> availability() async {
    switch (_availability) {
      case TtsAvailability.ready:
      case TtsAvailability.localeUnavailable:
        return _availability;
      case TtsAvailability.engineUnreachable:
        final DateTime? probedAt = _probedAt;
        if (probedAt != null &&
            _now().difference(probedAt) < kTtsReprobeAfter) {
          return _availability;
        }
        // The verdict has aged: the engine is asked again, with everything a
        // fresh answer deserves rather than the stale one.
        return _prepare(force: true);
      case TtsAvailability.unknown:
        // Nothing heard yet, or a probe already in flight: share it.
        return _prepare();
    }
  }

  /// Reads [text] aloud, when this device has a voice for [TtsVoice.locale].
  ///
  /// Completes when the engine is done, when the wait is judged exhausted, or
  /// immediately when the device cannot speak - never later than one of those three,
  /// because a caller waiting on a promise the engine has abandoned would leave the
  /// microphone closed and cost the merchant the voice itself.
  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    // The moment this sentence was asked for: a stop that lands afterwards cancels
    // it. Without the mark, a recap still warming its engine would be spoken over
    // the microphone that was opened to replace it.
    final int asked = _stopEpoch;
    if (await availability() != TtsAvailability.ready) {
      return;
    }
    if (_stopEpoch != asked) {
      // Cancelled while the engine was being prepared, by the very stop that is
      // opening the microphone. Nothing was said and nothing waits on us.
      return;
    }

    // The sentence before this one, finished or given up on. Waiting for it is what
    // makes the rule hold without trusting three engines that each break it
    // differently: Android drops the newcomer without a word, iOS queues it, and the
    // web engine throws it away.
    final Completer<void> previous =
        _current ?? (Completer<void>()..complete());
    final Completer<void> mine = Completer<void>();
    _current = mine;
    await previous.future;

    try {
      if (_stopEpoch != asked) {
        // Cancelled while queued behind the previous sentence. The chain is
        // released in the finally below, so the sentence after us gets its turn.
        return;
      }
      // Whatever the native queue mode does, this is what makes the sentence that
      // replaces this one replace it.
      await _quietly(device.stop);

      if (kDebugMode) {
        debugPrint('[PlatformTts] Speaking: "$text"');
      }

      final bool spoken = await _within(
        _deadlineFor(text),
        () => device.say(text),
        exhausted: false,
      );

      if (!spoken && kDebugMode) {
        debugPrint('[PlatformTts] The engine did not speak the sentence.');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] PlatformException while speaking: $e');
      }
    } on MissingPluginException catch (e) {
      // The plugin is absent on this platform entirely. That is a fact about the
      // build, not a failure to report, and it must not travel any further.
      if (kDebugMode) {
        debugPrint('[PlatformTts] TTS plugin is not available: $e');
      }
    } on Exception catch (e) {
      // The engine is a boundary: no failure it throws must reach the session,
      // which would leave the microphone closed over a recap that was already
      // on screen.
      if (kDebugMode) {
        debugPrint('[PlatformTts] Unexpected failure while speaking: $e');
      }
    } finally {
      if (!mine.isCompleted) {
        mine.complete();
      }
      if (identical(_current, mine)) {
        _current = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    // Up the epoch so no sentence asked for earlier is spoken after this stop,
    // release whoever is waiting to speak next, then silence the engine.
    // Releasing first is what lets the microphone open at once: the caller that
    // stops the recap is on its way to listening, and must not queue behind a
    // sentence it just cancelled.
    _stopEpoch++;
    final Completer<void>? pending = _current;
    _current = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    await _quietly(device.stop);
  }

  /// Configures the engine the first time a sentence is asked for, and records what
  /// the engine said about the shop's language.
  ///
  /// Lazy rather than done at startup: opening the microphone and warming a
  /// synthesiser at the same time is what makes a kiosk stutter, and nothing needs
  /// the voice until the merchant says something.
  Future<TtsAvailability> _prepare({bool force = false}) {
    if (force) {
      _preparation = null;
    }
    return _preparation ??= _prepareOnce();
  }

  Future<TtsAvailability> _prepareOnce() async {
    final TtsVoice voice = settings.ttsVoice;
    if (kDebugMode) {
      debugPrint(
        '[PlatformTts] Preparing TTS engine for locale "${voice.locale}"...',
      );
    }
    TtsAvailability verdict;
    try {
      final TtsProbe probe = await device.probe(voice.locale);
      if (probe == TtsProbe.available) {
        await _configure(voice);
      }
      verdict = switch (probe) {
        TtsProbe.available => TtsAvailability.ready,
        TtsProbe.localeUnavailable => TtsAvailability.localeUnavailable,
        TtsProbe.engineUnreachable => TtsAvailability.engineUnreachable,
      };
    } on PlatformException catch (e) {
      verdict = TtsAvailability.engineUnreachable;
      if (kDebugMode) {
        debugPrint(
          '[PlatformTts] PlatformException during TTS preparation: $e',
        );
      }
    } on MissingPluginException catch (e) {
      verdict = TtsAvailability.engineUnreachable;
      if (kDebugMode) {
        debugPrint('[PlatformTts] TTS plugin is not available: $e');
      }
    } catch (e) {
      verdict = TtsAvailability.engineUnreachable;
      if (kDebugMode) {
        debugPrint('[PlatformTts] Unexpected failure while preparing: $e');
      }
    }

    _availability = verdict;
    _probedAt = _now();

    if (verdict != TtsAvailability.ready && kDebugMode) {
      debugPrint('[PlatformTts] Engine verdict: ${verdict.name}.');
    }
    return verdict;
  }

  Future<void> _configure(TtsVoice voice) async {
    try {
      await device.configure(
        locale: voice.locale,
        rate: voice.rate,
        pitch: voice.pitch,
        volume: voice.volume,
      );
      if (kDebugMode) {
        debugPrint(
          '[PlatformTts] TTS engine successfully prepared and configured.',
        );
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] PlatformException while configuring: $e');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] TTS plugin is not available: $e');
      }
    }
  }

  /// How long [text] may take, from the length of the text and the pace asked for.
  ///
  /// A backstop rather than a measurement: it exists so that an engine which never
  /// answers costs one recap instead of the whole session. It is deliberately
  /// generous, because the failure this guards against is an engine that has
  /// abandoned the utterance, and an engine in trouble takes longer than one working
  /// normally.
  Duration _deadlineFor(String text) {
    final double rate = settings.ttsVoice.rate.clamp(0.1, 2.0);
    final int spoken = (text.length * kTtsMsPerCharAtUnitRate / rate).round();
    final Duration deadline = kTtsEngineGrace + Duration(milliseconds: spoken);
    return deadline > kTtsMaxSpeakDeadline ? kTtsMaxSpeakDeadline : deadline;
  }

  /// Runs [action] and gives up on it after [deadline], answering [exhausted].
  ///
  /// Giving up means the engine is told to stop, because a synthesiser left talking
  /// over a merchant who has already moved on is worse than a silent one.
  Future<T> _within<T>(
    Duration deadline,
    Future<T> Function() action, {
    required T exhausted,
  }) async {
    try {
      return await action().timeout(deadline);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[PlatformTts] The engine went quiet for too long.');
      }
      await _quietly(device.stop);
      return exhausted;
    }
  }

  /// Runs a call whose failure the merchant must never see.
  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] PlatformException: $e');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] TTS plugin is not available: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PlatformTts] Unexpected failure: $e');
      }
    }
  }
}
