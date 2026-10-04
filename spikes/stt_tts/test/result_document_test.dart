import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stt_tts_spike/src/measurement.dart';
import 'package:stt_tts_spike/src/platform_facts.dart';
import 'package:stt_tts_spike/src/result_document.dart';
import 'package:stt_tts_spike/src/spike_stt.dart';
import 'package:stt_tts_spike/src/spike_tts.dart';

/// The report is what the ADR will be argued from, so it has to carry the
/// conditions and not only the outcome, and it has to be readable as a whole before
/// anyone decides anything from it.
void main() {
  const DeviceFacts device = DeviceFacts(
    manufacturer: 'Samsung',
    model: 'SM-G970F',
    androidRelease: '12',
    sdkInt: 31,
  );
  const OfflineFacts offline = OfflineFacts(internetGranted: false);
  const SttReadiness readiness = SttReadiness(
    available: true,
    microphoneGranted: true,
    localeIds: <String>['fr_FR'],
  );
  const TtsReport tts = TtsReport(
    frenchVoices: <String>['fr-FR'],
    startLatency: Duration(milliseconds: 300),
  );
  const List<PhraseMeasurement> measurements = <PhraseMeasurement>[
    PhraseMeasurement(
      phraseId: 't001',
      reference: 'vendu un lait',
      heard: 'vendu un lait',
      latency: Duration(milliseconds: 900),
    ),
    PhraseMeasurement(
      phraseId: 't042',
      reference: 'combien de riz',
      heard: 'combien de',
      latency: Duration(milliseconds: 1200),
    ),
  ];

  ResultDocument build() {
    return ResultDocument.from(
      config: const SpikeConfig(),
      device: device,
      offline: offline,
      readiness: readiness,
      measurements: measurements,
      tts: tts,
    );
  }

  group('le rapport', () {
    test('porte un schema identifiable', () {
      expect(build().toJson()['schema'], 'voice-stt-spike/1');
    });

    test('porte les conditions: telephone, permission, locale, voix', () {
      final Map<String, Object?> json = build().toJson();

      expect((json['device']! as Map<String, Object?>)['model'], 'SM-G970F');
      expect(
        (json['offline']! as Map<String, Object?>)['provesOffline'],
        isTrue,
      );
      expect(json['config'], containsPair('localeId', 'fr_FR'));
      expect(json['config'], containsPair('onDevice', true));
      expect((json['tts']! as Map<String, Object?>)['startLatencyMs'], 300);
    });

    test('porte chaque phrase mesuree, avec sa reference', () {
      final List<Object?> rows =
          build().toJson()['measurements']! as List<Object?>;

      expect(rows, hasLength(2));
      expect(
        (rows.first! as Map<String, Object?>)['reference'],
        'vendu un lait',
      );
    });

    test('porte un resume calcule sur le corpus', () {
      final Map<String, Object?> summary =
          build().toJson()['summary']! as Map<String, Object?>;

      expect(summary['measured'], 2);
      // "combien de" contre "combien de riz": un mot manque sur six.
      expect(summary['referenceWords'], 6);
      expect(summary['wordErrorRateFolded'], 0.1667);
    });

    test('classe les mauvaises phrases de la pire a la meilleure', () {
      expect(
        build().worstOffenders.map((PhraseMeasurement m) => m.phraseId),
        <String>['t042'],
      );
    });

    test('ignore les phrases parfaites dans la liste des mauvaises', () {
      final ResultDocument perfect = ResultDocument.from(
        config: const SpikeConfig(),
        device: device,
        offline: offline,
        readiness: readiness,
        measurements: const <PhraseMeasurement>[
          PhraseMeasurement(
            phraseId: 't001',
            reference: 'vendu un lait',
            heard: 'vendu un lait',
            latency: Duration(milliseconds: 900),
          ),
        ],
        tts: tts,
      );

      expect(perfect.worstOffenders, isEmpty);
    });

    test('s encode en JSON relisible, avec un retour a la ligne final', () {
      final String encoded = build().encode();

      expect(encoded.endsWith('\n'), isTrue);
      expect(jsonDecode(encoded), isA<Map<String, Object?>>());
    });
  });

  group('les faits lus sur la machine', () {
    test('un telephone se nomme pour l ADR', () {
      expect(device.label, 'Samsung SM-G970F (Android 12, API 31)');
    });

    test('une permission accordee est signalee comme telle', () {
      expect(const OfflineFacts(internetGranted: true).provesOffline, isFalse);
      expect(offline.provesOffline, isTrue);
    });
  });
}
