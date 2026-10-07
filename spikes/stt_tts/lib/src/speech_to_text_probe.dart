import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import 'measurement.dart';
import 'spike_stt.dart';

/// Drives `speech_to_text`, the candidate the spike is here to judge.
///
/// Two settings carry the whole point of the measurement and must not be dropped
/// when this is adapted in step 1c: `onDevice: true`, and the absence of the
/// `INTERNET` permission in the manifest. Together they mean a transcription that
/// came out was produced on the phone. Drop either one and the measurement
/// silently becomes a measurement of a network service.
///
/// The plugin reports errors through the listener given to `initialize`, not
/// through `listen`, so the pending listen is settled from that one listener. A
/// device that never reports a final result and never reports an error would
/// otherwise hang the pass, hence the deadline.
final class SpeechToTextProbe implements SpikeStt {
  SpeechToTextProbe({SpeechToText? engine})
    : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  Completer<SttOutcome>? _pending;
  Stopwatch? _stopwatch;

  /// `listenFor` plus the silence window plus the time the platform needs to hand
  /// back a final result.
  static const Duration _passDeadline = Duration(seconds: 12);

  @override
  Future<SttReadiness> prepare() async {
    try {
      final bool ready = await _engine.initialize(
        onError: (error) {
          _settle(
            SttOutcome(
              transcript: '',
              latency: _stopwatch?.elapsed ?? Duration.zero,
              error: error.errorMsg,
            ),
          );
        },
        onStatus: (String _) {},
      );
      if (!ready) {
        return const SttReadiness(
          available: false,
          microphoneGranted: false,
          localeIds: <String>[],
          error: 'initialisation refusee',
        );
      }
      final bool granted = await _engine.hasPermission;
      final List<LocaleName> locales = await _engine.locales();
      return SttReadiness(
        available: true,
        microphoneGranted: granted,
        localeIds: locales.map((LocaleName locale) => locale.localeId).toList(),
      );
    } on Object catch (error) {
      return SttReadiness(
        available: false,
        microphoneGranted: false,
        localeIds: <String>[],
        error: error.toString(),
      );
    }
  }

  @override
  Future<SttOutcome> listenOnce({required String localeId}) async {
    _stopwatch = Stopwatch()..start();
    final Completer<SttOutcome> settled = Completer<SttOutcome>();
    _pending = settled;

    try {
      await _engine.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(milliseconds: 8000),
          pauseFor: const Duration(milliseconds: 1500),
          onDevice: SpikeConfig.onDevice,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (result.finalResult) {
            final String words = result.recognizedWords.trim();
            _settle(
              words.isEmpty
                  ? SttOutcome(
                      transcript: '',
                      latency: _stopwatch?.elapsed ?? Duration.zero,
                      error: 'aucune transcription',
                    )
                  : SttOutcome(
                      transcript: words,
                      latency: _stopwatch?.elapsed ?? Duration.zero,
                    ),
            );
          }
        },
      );
      return await settled.future.timeout(
        _passDeadline,
        onTimeout: () {
          final String? reported = _engine.lastError?.errorMsg;
          return SttOutcome(
            transcript: '',
            latency: _stopwatch?.elapsed ?? Duration.zero,
            error: reported ?? 'delai depasse sans resultat final',
          );
        },
      );
    } on Object catch (error) {
      return SttOutcome(
        transcript: '',
        latency: _stopwatch?.elapsed ?? Duration.zero,
        error: error.toString(),
      );
    } finally {
      _pending = null;
      _stopwatch = null;
      await _engine.stop();
    }
  }

  void _settle(SttOutcome outcome) {
    final Completer<SttOutcome>? pending = _pending;
    _stopwatch?.stop();
    if (pending != null && !pending.isCompleted) {
      pending.complete(outcome);
    }
  }
}
