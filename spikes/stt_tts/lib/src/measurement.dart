import 'accuracy.dart';

/// What the pipeline asks the spike to measure, in one place so a result always
/// records the conditions it was taken under.
class SpikeConfig {
  const SpikeConfig({
    this.localeId = 'fr_FR',
    this.listenFor = const Duration(milliseconds: 8000),
    this.pauseFor = const Duration(milliseconds: 1500),
  });

  /// `onDevice` is not a preference: it is what makes the measurement prove
  /// something. On Android it selects the on device recogniser, which fails
  /// rather than falling back to the network when the language pack is missing.
  static const bool onDevice = true;

  final String localeId;

  /// Longest a phrase may take before the recogniser gives up.
  final Duration listenFor;

  /// Silence after which a phrase is considered finished.
  final Duration pauseFor;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'localeId': localeId,
      'onDevice': onDevice,
      'listenForMs': listenFor.inMilliseconds,
      'pauseForMs': pauseFor.inMilliseconds,
    };
  }
}

/// What one phrase produced.
final class PhraseMeasurement {
  const PhraseMeasurement({
    required this.phraseId,
    required this.reference,
    required this.heard,
    required this.latency,
    this.failure,
  });

  factory PhraseMeasurement.fromJson(Map<String, Object?> json) {
    return PhraseMeasurement(
      phraseId: json['phraseId']! as String,
      reference: json['reference']! as String,
      heard: (json['heard'] as String?) ?? '',
      latency: Duration(milliseconds: (json['latencyMs'] as int?) ?? 0),
      failure: json['failure'] as String?,
    );
  }

  final String phraseId;
  final String reference;

  /// What the recogniser returned, empty when it returned nothing at all.
  final String heard;

  /// From the moment listening started to the final result.
  final Duration latency;

  /// Why the phrase produced no transcription, when it produced none.
  final String? failure;

  /// Whether the information survived: accents, punctuation and number spelling
  /// ignored. This is the rate the decision is taken on, because a difference the
  /// application already tolerates is not a defect.
  WordErrorRate get foldedRate =>
      wordErrorRate(reference: reference, heard: heard);

  /// How different the two strings look, nothing forgiven.
  WordErrorRate get literalRate =>
      wordErrorRateOfWords(literalWords(reference), literalWords(heard));

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'phraseId': phraseId,
      'reference': reference,
      'heard': heard,
      'latencyMs': latency.inMilliseconds,
      'foldedErrors': foldedRate.errors,
      'literalErrors': literalRate.errors,
      'referenceWords': foldedRate.referenceWords,
      if (failure != null) 'failure': failure,
    };
  }
}

/// The numbers the decision is taken on.
final class RunSummary {
  const RunSummary({
    required this.measured,
    required this.failed,
    required this.errors,
    required this.referenceWords,
    required this.rawErrors,
    required this.medianLatency,
    required this.p95Latency,
  });

  factory RunSummary.from(List<PhraseMeasurement> measurements) {
    return RunSummary(
      measured: measurements.length,
      failed: measurements
          .where((PhraseMeasurement m) => m.failure != null)
          .length,
      errors: measurements.fold(
        0,
        (int sum, PhraseMeasurement m) => sum + m.foldedRate.errors,
      ),
      referenceWords: measurements.fold(
        0,
        (int sum, PhraseMeasurement m) => sum + m.foldedRate.referenceWords,
      ),
      rawErrors: measurements.fold(
        0,
        (int sum, PhraseMeasurement m) => sum + m.literalRate.errors,
      ),
      medianLatency: Duration(
        milliseconds: _percentile(
          measurements.map((PhraseMeasurement m) => m.latency.inMilliseconds),
          0.5,
        ),
      ),
      p95Latency: Duration(
        milliseconds: _percentile(
          measurements.map((PhraseMeasurement m) => m.latency.inMilliseconds),
          0.95,
        ),
      ),
    );
  }

  final int measured;
  final int failed;
  final int errors;
  final int referenceWords;
  final int rawErrors;
  final Duration medianLatency;
  final Duration p95Latency;

  /// Corpus rate, not the mean of per phrase rates: averaging ratios gives a
  /// three word phrase the same weight as a nine word one.
  double get rate => referenceWords == 0 ? 0 : errors / referenceWords;

  double get literalRate =>
      referenceWords == 0 ? 0 : rawErrors / referenceWords;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'measured': measured,
      'failed': failed,
      'wordErrorRateFolded': double.parse(rate.toStringAsFixed(4)),
      'wordErrorRateLiteral': double.parse(literalRate.toStringAsFixed(4)),
      'referenceWords': referenceWords,
      'medianLatencyMs': medianLatency.inMilliseconds,
      'p95LatencyMs': p95Latency.inMilliseconds,
    };
  }
}

/// Nearest rank percentile on a sorted copy. The pipeline asks for a median and a
/// p95, and interpolating a p95 over thirty samples would invent precision.
int _percentile(Iterable<int> values, double fraction) {
  final List<int> sorted = values.toList()..sort();
  if (sorted.isEmpty) {
    return 0;
  }
  final int rank = (fraction * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}
