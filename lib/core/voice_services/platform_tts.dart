import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;

import 'device_speech_speaker.dart';
import 'tts_port.dart';
import 'voice_service_settings.dart';

/// The synthesiser of the device, behind the port the module uses.
///
/// Two jobs: prepare the engine once, and never let a sentence survive the one
/// that follows it. A device that cannot speak is not an error the caller has to
/// handle, because every sentence spoken here is also on screen.
final class PlatformTts implements TtsPort {
  PlatformTts({required this.device, required this.settings});

  /// The engine of the device, injected so the rules below can be tested without
  /// one.
  final DeviceSpeechSpeaker device;

  final VoiceServiceSettings settings;

  bool _prepared = false;
  bool _supported = true;

  /// Reads [text] aloud, when this device has a voice for [TtsVoice.locale].
  ///
  /// A device that cannot speak the shop's language stays silent rather than
  /// falling back to whatever voice it has: a recap read in the wrong language is
  /// worse than a recap the merchant reads on screen, and the screen is always
  /// there.
  @override
  Future<void> speak(String text) async {
    await _prepare();
    if (!_supported || text.trim().isEmpty) {
      return;
    }
    try {
      await device.say(text);
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await device.stop();
    } on PlatformException {
      return;
    }
  }

  /// Configures the engine the first time a sentence is asked for.
  ///
  /// Lazy rather than done at startup: opening the microphone and warming a
  /// synthesiser at the same time is what makes a kiosk stutter, and nothing
  /// needs the voice until the merchant says something.
  Future<void> _prepare() async {
    if (_prepared) {
      return;
    }
    _prepared = true;
    final TtsVoice voice = settings.ttsVoice;
    try {
      if (!await device.supports(voice.locale)) {
        _supported = false;
        return;
      }
      await device.configure(
        locale: voice.locale,
        rate: voice.rate,
        pitch: voice.pitch,
        volume: voice.volume,
      );
    } on PlatformException {
      _supported = false;
    }
  }
}
