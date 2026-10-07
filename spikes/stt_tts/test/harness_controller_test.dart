import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stt_tts_spike/src/harness_controller.dart';
import 'package:stt_tts_spike/src/measurement.dart';
import 'package:stt_tts_spike/src/phrase_book.dart';
import 'package:stt_tts_spike/src/spike_stt.dart';
import 'package:stt_tts_spike/src/spike_tts.dart';

/// The pass is ordinary logic: which phrase comes next, what happens when one comes
/// back empty, when the run is over, and when no report may be produced. Running it
/// here against a fake recogniser is the only way to check that logic at all, since
/// the real thing needs a phone in a shop.
const MethodChannel _deviceChannel = MethodChannel('stt_tts_spike/device');

PhraseBook _book(List<String> texts) {
  return PhraseBook(
    source: 'test',
    phrases: <SpikePhrase>[
      for (int i = 0; i < texts.length; i++)
        SpikePhrase(id: 't$i', text: texts[i], tags: const <String>['simple']),
    ],
  );
}

void _deviceChannelAnswers({bool internet = false, bool respond = true}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_deviceChannel, (MethodCall call) async {
        if (!respond) {
          return null;
        }
        return switch (call.method) {
          'hasInternetPermission' => internet,
          'describe' => <String, Object?>{
            'manufacturer': 'Samsung',
            'model': 'SM-G970F',
            'androidRelease': '12',
            'sdkInt': 31,
          },
          _ => null,
        };
      });
}

/// A recogniser that hands back a scripted outcome per call, and remembers what it
/// was asked to listen for.
final class _FakeStt implements SpikeStt {
  _FakeStt(this._outcomes);

  final List<SttOutcome> _outcomes;
  final List<String> requestedLocales = <String>[];
  int prepareCalls = 0;

  @override
  Future<SttReadiness> prepare() async {
    prepareCalls++;
    return const SttReadiness(
      available: true,
      microphoneGranted: true,
      localeIds: <String>['fr_FR', 'en_US'],
    );
  }

  @override
  Future<SttOutcome> listenOnce({required String localeId}) async {
    requestedLocales.add(localeId);
    if (_outcomes.isEmpty) {
      return const SttOutcome(
        transcript: '',
        latency: Duration.zero,
        error: 'plus de scenario',
      );
    }
    return _outcomes.removeAt(0);
  }
}

final class _FakeTts implements SpikeTts {
  @override
  Future<List<String>> availableLanguages() async => <String>['fr-FR', 'en-US'];

  @override
  Future<TtsReport> speakOnce({
    required String language,
    required String text,
  }) async {
    return TtsReport(
      frenchVoices: <String>['fr-FR'],
      startLatency: const Duration(milliseconds: 300),
    );
  }
}

final class _SilentTts implements SpikeTts {
  @override
  Future<List<String>> availableLanguages() async => <String>['en-US'];

  @override
  Future<TtsReport> speakOnce({
    required String language,
    required String text,
  }) async {
    return const TtsReport(
      frenchVoices: <String>[],
      startLatency: null,
      error: 'aucune voix',
    );
  }
}

final class _NoMicrophoneStt implements SpikeStt {
  @override
  Future<SttReadiness> prepare() async {
    return const SttReadiness(
      available: true,
      microphoneGranted: false,
      localeIds: <String>['en_US'],
    );
  }

  @override
  Future<SttOutcome> listenOnce({required String localeId}) async {
    return const SttOutcome(
      transcript: '',
      latency: Duration.zero,
      error: 'refus',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _deviceChannelAnswers();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceChannel, null);
  });

  group('le diagnostic', () {
    test('lit le telephone et la permission avant toute mesure', () async {
      _deviceChannelAnswers(internet: false);
      final _FakeStt stt = _FakeStt(<SttOutcome>[]);
      final HarnessController controller = HarnessController(
        stt: stt,
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );

      expect(controller.stage, PassStage.idle);
      expect(controller.report, isNull, reason: 'rien avant le diagnostic');

      await controller.prepare();

      expect(controller.stage, PassStage.ready);
      expect(stt.prepareCalls, 1);
      expect(controller.device?.model, 'SM-G970F');
      expect(controller.offline?.provesOffline, isTrue);
    });

    test('demande la reconnaissance embarquee, en francais', () async {
      final _FakeStt stt = _FakeStt(<SttOutcome>[]);
      final HarnessController controller = HarnessController(
        stt: stt,
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );
      await controller.prepare();

      await controller.measureCurrent();

      expect(stt.requestedLocales, <String>['fr_FR']);
    });

    test('refuse de conclure hors-ligne quand INTERNET est accordee', () async {
      _deviceChannelAnswers(internet: true);
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );

      await controller.prepare();

      expect(controller.offline?.provesOffline, isFalse);
      expect(controller.readinessError, contains('INTERNET'));
    });

    test('signale un microphone refuse', () async {
      final HarnessController controller = HarnessController(
        stt: _NoMicrophoneStt(),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );

      await controller.prepare();

      expect(controller.readinessError, contains('Microphone'));
    });

    test('signale une voix de synthese absente', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[]),
        tts: _SilentTts(),
        book: _book(<String>['vendu un lait']),
      );

      await controller.prepare();

      expect(controller.readinessError, contains('Aucune voix francaise'));
    });

    test('reste muet quand tout va bien', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );

      await controller.prepare();

      expect(controller.readinessError, isNull);
    });

    test(
      'ne pretend pas avoir prouve le hors-ligne quand le canal est muet',
      () async {
        // Un canal qui ne repond pas ne vaut pas mieux qu'une permission accordee:
        // dans les deux cas la mesure ne prouve rien, et le rapport doit le dire.
        _deviceChannelAnswers(respond: false);
        final HarnessController controller = HarnessController(
          stt: _FakeStt(<SttOutcome>[]),
          tts: _FakeTts(),
          book: _book(<String>['vendu un lait']),
        );

        await controller.prepare();

        expect(controller.offline?.provesOffline, isFalse);
        expect(controller.offline?.error, isNotNull);
      },
    );
  });

  group('la passe', () {
    test('avance d une phrase a la fois, dans l ordre du jeu', () async {
      final _FakeStt stt = _FakeStt(<SttOutcome>[
        const SttOutcome(
          transcript: 'vendu un lait',
          latency: Duration(milliseconds: 900),
        ),
        const SttOutcome(
          transcript: 'vendu deux savon',
          latency: Duration(milliseconds: 800),
        ),
      ]);
      final HarnessController controller = HarnessController(
        stt: stt,
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait', 'vendu deux savon']),
      );
      await controller.prepare();

      expect(controller.currentPhrase?.text, 'vendu un lait');
      await controller.measureCurrent();
      expect(controller.currentPhrase?.text, 'vendu deux savon');
      await controller.measureCurrent();

      expect(
        controller.measurements.map((PhraseMeasurement m) => m.reference),
        <String>['vendu un lait', 'vendu deux savon'],
      );
      expect(controller.isFinished, isTrue);
    });

    test('termine la passe sur la derniere phrase', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[
          const SttOutcome(
            transcript: 'vendu un lait',
            latency: Duration(milliseconds: 900),
          ),
        ]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );
      await controller.prepare();

      await controller.measureCurrent();

      expect(controller.isFinished, isTrue);
      expect(controller.stage, PassStage.finished);
      expect(controller.currentPhrase, isNull);
    });

    test(
      'conserve un echec comme une mesure, pas comme une perte de phrase',
      () async {
        final HarnessController controller = HarnessController(
          stt: _FakeStt(<SttOutcome>[
            const SttOutcome(
              transcript: '',
              latency: Duration(seconds: 8),
              error: 'no_match',
            ),
            const SttOutcome(
              transcript: 'vendu deux savon',
              latency: Duration(milliseconds: 700),
            ),
          ]),
          tts: _FakeTts(),
          book: _book(<String>['combien de riz', 'vendu deux savon']),
        );
        await controller.prepare();

        await controller.measureCurrent();
        await controller.measureCurrent();

        expect(controller.measurements.first.failure, 'no_match');
        expect(controller.measurements.first.reference, 'combien de riz');
        expect(controller.measurements, hasLength(2));
        expect(controller.summary.failed, 1);
        expect(controller.summary.measured, 2);
      },
    );

    test('ignore un second appui pendant qu une ecoute est en cours', () async {
      // Deux appis rapides ne doivent pas perdre une phrase ni en sauter une.
      final Completer<void> gate = Completer<void>();
      final _GatedStt stt = _GatedStt(gate);
      final HarnessController controller = HarnessController(
        stt: stt,
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait', 'vendu deux savon']),
      );
      await controller.prepare();

      final Future<void> first = controller.measureCurrent();
      await Future<void>.delayed(Duration.zero);
      final Future<void> second = controller.measureCurrent();
      expect(controller.isListening, isTrue);
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(controller.measurements, hasLength(1));
      expect(controller.index, 1);
    });

    test(
      'reprendre revient a la phrase precedente et oublie sa mesure',
      () async {
        final HarnessController controller = HarnessController(
          stt: _FakeStt(<SttOutcome>[
            const SttOutcome(
              transcript: 'rien du tout',
              latency: Duration(milliseconds: 900),
            ),
            const SttOutcome(
              transcript: 'vendu un lait',
              latency: Duration(milliseconds: 900),
            ),
          ]),
          tts: _FakeTts(),
          book: _book(<String>['vendu un lait', 'combien de riz']),
        );
        await controller.prepare();

        await controller.measureCurrent();
        controller.retryCurrent();

        expect(controller.measurements, isEmpty);
        expect(controller.index, 0);
        expect(controller.currentPhrase?.text, 'vendu un lait');

        await controller.measureCurrent();

        expect(controller.measurements.single.heard, 'vendu un lait');
      },
    );

    test('recommencer vide la passe et revient au debut', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[
          const SttOutcome(
            transcript: 'a',
            latency: Duration(milliseconds: 900),
          ),
          const SttOutcome(
            transcript: 'b',
            latency: Duration(milliseconds: 900),
          ),
        ]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait', 'combien de riz']),
      );
      await controller.prepare();
      await controller.measureCurrent();
      await controller.measureCurrent();

      controller.restart();

      expect(controller.measurements, isEmpty);
      expect(controller.index, 0);
      expect(controller.isFinished, isFalse);
      expect(controller.report, isNull);
    });

    test('reprendre sans avoir mesure ne fait rien', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );
      await controller.prepare();

      controller.retryCurrent();

      expect(controller.index, 0);
      expect(controller.measurements, isEmpty);
    });
  });

  group('le rapport', () {
    Future<HarnessController> finished() async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[
          const SttOutcome(
            transcript: 'vendu un lait',
            latency: Duration(milliseconds: 900),
          ),
        ]),
        tts: _FakeTts(),
        book: _book(<String>['vendu un lait']),
      );
      await controller.prepare();
      await controller.measureCurrent();
      return controller;
    }

    test('n existe pas avant la fin de la passe', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[
          const SttOutcome(transcript: 'a', latency: Duration(milliseconds: 1)),
          const SttOutcome(transcript: 'b', latency: Duration(milliseconds: 1)),
        ]),
        tts: _FakeTts(),
        book: _book(<String>['a', 'b']),
      );
      await controller.prepare();
      await controller.measureCurrent();

      expect(controller.measurements, hasLength(1));
      expect(
        controller.report,
        isNull,
        reason: 'une passe a moitie ne se rapporte pas',
      );
    });

    test(
      'porte les conditions et la synthese quand la passe est finie',
      () async {
        final HarnessController controller = await finished();

        final report = controller.report;
        expect(report, isNotNull);
        expect(report!.device.model, 'SM-G970F');
        expect(report.offline.provesOffline, isTrue);
        expect(report.tts.startLatency, const Duration(milliseconds: 300));
        expect(report.measurements, hasLength(1));
      },
    );

    test('classe les mauvaises phrases de la pire a la meilleure', () async {
      final HarnessController controller = HarnessController(
        stt: _FakeStt(<SttOutcome>[
          const SttOutcome(
            transcript: 'vendu un lait',
            latency: Duration(milliseconds: 900),
          ),
          const SttOutcome(
            transcript: 'combien de',
            latency: Duration(milliseconds: 900),
          ),
          const SttOutcome(
            transcript: 'annule la vente de riz',
            latency: Duration(milliseconds: 900),
          ),
        ]),
        tts: _FakeTts(),
        book: _book(<String>[
          'vendu un lait',
          'combien de riz',
          'annule la vente de riz',
        ]),
      );
      await controller.prepare();
      await controller.measureCurrent();
      await controller.measureCurrent();
      await controller.measureCurrent();

      final report = controller.report!;

      expect(
        report.worstOffenders.map((PhraseMeasurement m) => m.phraseId),
        <String>['t1'],
      );
    });
  });
}

/// A recogniser whose listen only returns once the test lets it.
final class _GatedStt implements SpikeStt {
  _GatedStt(this._gate);

  final Completer<void> _gate;

  @override
  Future<SttReadiness> prepare() async {
    return const SttReadiness(
      available: true,
      microphoneGranted: true,
      localeIds: <String>['fr_FR'],
    );
  }

  @override
  Future<SttOutcome> listenOnce({required String localeId}) async {
    await _gate.future;
    return const SttOutcome(
      transcript: 'vendu un lait',
      latency: Duration(milliseconds: 900),
    );
  }
}
