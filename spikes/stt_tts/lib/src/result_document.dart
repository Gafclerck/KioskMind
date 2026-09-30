import 'dart:convert';

import 'measurement.dart';
import 'platform_facts.dart';
import 'spike_stt.dart';
import 'spike_tts.dart';

/// What one whole spike run produced, ready to be pasted into the ADR.
///
/// The document is built as a value first and only turned into text at the very
/// end, so a result can be asserted in a test without a device. It carries the
/// conditions, not just the outcome: a WER without the locale, the build and the
/// phone attached to it cannot be reproduced or challenged.
final class ResultDocument {
  const ResultDocument({
    required this.config,
    required this.device,
    required this.offline,
    required this.readiness,
    required this.measurements,
    required this.tts,
  });

  factory ResultDocument.from({
    required SpikeConfig config,
    required DeviceFacts device,
    required OfflineFacts offline,
    required SttReadiness readiness,
    required List<PhraseMeasurement> measurements,
    required TtsReport tts,
  }) {
    return ResultDocument(
      config: config,
      device: device,
      offline: offline,
      readiness: readiness,
      measurements: measurements,
      tts: tts,
    );
  }

  final SpikeConfig config;
  final DeviceFacts device;
  final OfflineFacts offline;
  final SttReadiness readiness;
  final List<PhraseMeasurement> measurements;
  final TtsReport tts;

  RunSummary get summary => RunSummary.from(measurements);

  /// The phrases that went wrong, worst first. This is the list the ADR has to
  /// read: an average says nothing about whether the failure is a recogniser that
  /// cannot hear a kiosk, or three specific words.
  List<PhraseMeasurement> get worstOffenders {
    final List<PhraseMeasurement> ranked =
        List<PhraseMeasurement>.of(measurements)
          ..sort((PhraseMeasurement a, PhraseMeasurement b) {
            final int byRate = b.foldedRate.ratio.compareTo(a.foldedRate.ratio);
            return byRate != 0 ? byRate : a.phraseId.compareTo(b.phraseId);
          });
    return ranked
        .where((PhraseMeasurement m) => m.foldedRate.errors > 0)
        .toList();
  }

  /// What the run establishes, stated as facts and not as a verdict. The verdict
  /// is the human's, in the ADR, against criteria written before the run.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema': 'voice-stt-spike/1',
      'config': config.toJson(),
      'device': device.toJson(),
      'offline': offline.toJson(),
      'stt': readiness.toJson(),
      'tts': tts.toJson(),
      'summary': summary.toJson(),
      'measurements': measurements
          .map((PhraseMeasurement m) => m.toJson())
          .toList(),
    };
  }

  String encode() {
    return '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
  }
}
