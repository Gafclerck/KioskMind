import 'dart:convert';
import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';

import 'routing_cases.dart';
import 'routing_harness.dart';

/// The three measures the pipeline is graded on, and the floor they are held to.
///
/// A single "percent exact" number hides the one failure that matters: a case the
/// pipeline executed when the frozen set expected it to stop. A merchant can undo
/// a wrong question, not a wrong sale that already recorded itself, so the four
/// cases below are sorted by what the pipeline *did*, and the dangerous one is
/// printed first and named.
///
/// The four partition the set. Nothing is left in a fifth "other" bucket, so a
/// case cannot be lost between the exact count and the total.
///
/// The tool and the tests read these numbers through this one file, so the output
/// of `voice_eval` and the assertions of the tests cannot say two different
/// things about the same code.

/// The text set, scored on what the merchant said.
const String textSetLabel = 'texte';

/// The set written from recordings, scored on what they say.
///
/// The name is deliberate. No recognizer has ever run on these 44 cases here, so
/// calling the result an audio measurement would be false: [RoutingScore]
/// reports how many recordings are actually on disk next to the score.
const String referenceSetLabel = 'transcription de reference';

const String textSetPath = 'voice/golden/text_cases.json';

/// Still named `audio_cases.json` on disk because the frozen set cannot be
/// touched; [referenceSetLabel] is what the set measures.
const String referenceSetPath = 'voice/golden/audio_cases.json';

/// The measured floors. Outside `voice/golden/`, which is frozen.
const String baselinePath = 'voice/baseline.json';

/// What one case ended as.
enum RoutingCaseKind {
  /// The pipeline called the expected handler with the expected arguments.
  exactExecuted,

  /// The pipeline asked or refused, as the case said.
  exactStopped,

  /// The pipeline acted when it should not have.
  ///
  /// The dangerous case: a sale or a restock recorded when the frozen set
  /// expected a confirmation, or an action of the wrong kind or arguments.
  wrongExecuted,

  /// The pipeline stopped, but not for the reason the case expected.
  ///
  /// Annoying, never harmful: nothing was written.
  wrongStopped,
}

/// One case, scored.
final class ScoredCase {
  const ScoredCase({
    required this.id,
    required this.utterance,
    required this.recording,
    required this.kind,
    required this.expected,
    required this.actual,
  });

  final String id;
  final String utterance;

  /// The recording the case was written from, if it declares one.
  final String? recording;
  final RoutingCaseKind kind;
  final String expected;
  final String actual;

  bool get hasRecording => recording != null;

  /// Whether the recording is on disk. A case can be scored without it, and
  /// saying so is the whole point of counting them.
  bool get recordingPresent =>
      recording != null && File(recording!).existsSync();
}

/// The four cases of one set, with the T1 parse latency of each case.
final class RoutingScore {
  RoutingScore({
    required this.label,
    required this.cases,
    required List<int> latenciesMicros,
  }) : _latencies = List<int>.of(latenciesMicros)..sort();

  final String label;
  final List<ScoredCase> cases;
  final List<int> _latencies;

  int get total => cases.length;

  int count(RoutingCaseKind kind) =>
      cases.where((ScoredCase c) => c.kind == kind).length;

  int get exactExecuted => count(RoutingCaseKind.exactExecuted);
  int get exactStopped => count(RoutingCaseKind.exactStopped);
  int get wrongExecuted => count(RoutingCaseKind.wrongExecuted);
  int get wrongStopped => count(RoutingCaseKind.wrongStopped);

  /// Cases judged exactly, whichever way they ended.
  int get exact => exactExecuted + exactStopped;

  /// The cases the pipeline executed when it should not have, by id.
  List<String> get wrongExecutedIds => <String>[
    for (final ScoredCase c in cases)
      if (c.kind == RoutingCaseKind.wrongExecuted) c.id,
  ];

  /// The same cases, with what was expected and what happened, to name them.
  List<ScoredCase> get wrongExecutedCases => cases
      .where((ScoredCase c) => c.kind == RoutingCaseKind.wrongExecuted)
      .toList();

  List<ScoredCase> get wrongStoppedCases => cases
      .where((ScoredCase c) => c.kind == RoutingCaseKind.wrongStopped)
      .toList();

  /// Cases of this set that were written from a recording, and how many of those
  /// recordings exist. Zero for the text set.
  int get casesWithRecording =>
      cases.where((ScoredCase c) => c.hasRecording).length;

  int get recordingsPresent =>
      cases.where((ScoredCase c) => c.recordingPresent).length;

  Duration get medianLatency => Duration(microseconds: _percentile(0.5));

  Duration get p95Latency => Duration(microseconds: _percentile(0.95));

  /// Nearest-rank percentile over the sorted latencies.
  ///
  /// The nearest-rank method needs no interpolation, so a p95 read here is a
  /// latency a case really took.
  int _percentile(double fraction) =>
      nearestRankPercentile(_latencies, fraction);

  /// One line, in the order the numbers are read: the dangerous one first.
  String get summary =>
      'mauvais routage execute $wrongExecuted/$total, '
      'exact execute $exactExecuted, '
      'clarifie ou refuse $exactStopped, '
      'arret incorrect $wrongStopped';
}

/// Nearest-rank percentile of a latency sample, in microseconds.
///
/// One implementation for the tool, the routing score and the text level, so the
/// median and the p95 quoted in three places cannot be three different numbers.
int nearestRankPercentile(List<int> micros, double fraction) {
  if (micros.isEmpty) {
    return 0;
  }
  final List<int> sorted = List<int>.of(micros)..sort();
  final int index = (fraction * sorted.length).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

/// Scores a frozen set, one case at a time, through the whole pipeline.
///
/// The latency measured here is the T1 parser alone. The turn re-parses
/// internally, and measuring that would need a seam cut into the use case; a
/// slightly clumsy second measurement beats a false precision. It is a figure of
/// this machine, not a product claim, which is why no test gates on it.
Future<RoutingScore> scoreSet({
  required String label,
  required List<FrozenCase> cases,
  required RoutingHarness harness,
}) async {
  final List<ScoredCase> scored = <ScoredCase>[];
  final List<int> latencies = <int>[];
  for (final FrozenCase testCase in cases) {
    final Stopwatch watch = Stopwatch()..start();
    final CommandProposal _ = harness.parser.parse(testCase.utterance);
    watch.stop();
    latencies.add(watch.elapsedMicroseconds);

    final Route route = await harness.run(
      testCase.utterance,
      answers: testCase.answers,
      withSession: testCase.undoesASale,
    );
    scored.add(
      ScoredCase(
        id: testCase.id,
        utterance: testCase.utterance,
        recording: testCase.recording,
        kind: kindOf(testCase, route, harness.primedSaleId),
        expected: expectedJson(testCase, harness.primedSaleId),
        actual: actualJson(route),
      ),
    );
  }
  return RoutingScore(label: label, cases: scored, latenciesMicros: latencies);
}

/// Sorts one comparison into one of the four cases.
///
/// Exactness is the judge's, read from the same two JSON strings it compares, so
/// the diagonal of this table is exactly the "percent exact" the tool used to
/// print on its own.
RoutingCaseKind kindOf(FrozenCase testCase, Route route, String? primedSaleId) {
  final bool acted = route.call != null;
  if (expectedJson(testCase, primedSaleId) == actualJson(route)) {
    return acted ? RoutingCaseKind.exactExecuted : RoutingCaseKind.exactStopped;
  }
  return acted ? RoutingCaseKind.wrongExecuted : RoutingCaseKind.wrongStopped;
}

/// The measured floors, read by the tests and written by `--write-baseline`.
final class RoutingBaseline {
  const RoutingBaseline({required this.sets});

  factory RoutingBaseline.of(List<RoutingScore> scores) {
    return RoutingBaseline(
      sets: <String, RoutingSetBaseline>{
        for (final RoutingScore score in scores)
          score.label: RoutingSetBaseline.of(score),
      },
    );
  }

  factory RoutingBaseline.from(Map<String, Object?> json) {
    final Object? raw = json['sets'];
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Base de reference: "sets" manquant');
    }
    return RoutingBaseline(
      sets: <String, RoutingSetBaseline>{
        for (final MapEntry<String, Object?> entry in raw.entries)
          if (entry.value is Map<String, Object?>)
            entry.key: RoutingSetBaseline.from(
              entry.key,
              entry.value! as Map<String, Object?>,
            ),
      },
    );
  }

  final Map<String, RoutingSetBaseline> sets;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': baselineVersion,
      'writtenOn': DateTime.now().toIso8601String().substring(0, 10),
      'note': _baselineNote,
      'sets': <String, Object?>{
        for (final MapEntry<String, RoutingSetBaseline> entry in sets.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}

/// The floors of one set.
final class RoutingSetBaseline {
  const RoutingSetBaseline({
    required this.key,
    required this.label,
    required this.total,
    required this.exactExecuted,
    required this.exactStopped,
    required this.wrongExecuted,
    required this.wrongStopped,
    required this.wrongExecutedIds,
    required this.latencyMedianMicros,
    required this.latencyP95Micros,
  });

  factory RoutingSetBaseline.of(RoutingScore score) {
    return RoutingSetBaseline(
      key: score.label,
      label: score.label,
      total: score.total,
      exactExecuted: score.exactExecuted,
      exactStopped: score.exactStopped,
      wrongExecuted: score.wrongExecuted,
      wrongStopped: score.wrongStopped,
      wrongExecutedIds: score.wrongExecutedIds,
      latencyMedianMicros: score.medianLatency.inMicroseconds,
      latencyP95Micros: score.p95Latency.inMicroseconds,
    );
  }

  factory RoutingSetBaseline.from(String key, Map<String, Object?> json) {
    return RoutingSetBaseline(
      key: key,
      label: json['label']! as String,
      total: json['total']! as int,
      exactExecuted: json['exactExecuted']! as int,
      exactStopped: json['exactStopped']! as int,
      wrongExecuted: json['wrongExecuted']! as int,
      wrongStopped: json['wrongStopped']! as int,
      wrongExecutedIds: <String>[
        for (final Object? id in json['wrongExecutedIds'] as List<Object?>)
          id! as String,
      ],
      latencyMedianMicros: json['latencyMedianMicros']! as int,
      latencyP95Micros: json['latencyP95Micros']! as int,
    );
  }

  final String key;
  final String label;
  final int total;
  final int exactExecuted;
  final int exactStopped;
  final int wrongExecuted;
  final int wrongStopped;
  final List<String> wrongExecutedIds;
  final int latencyMedianMicros;
  final int latencyP95Micros;

  /// The four cases added up, which must equal [total].
  int get bucketed =>
      exactExecuted + exactStopped + wrongExecuted + wrongStopped;

  String get summary =>
      'mauvais routage execute $wrongExecuted/$total, '
      'exact execute $exactExecuted, '
      'clarifie ou refuse $exactStopped, '
      'arret incorrect $wrongStopped';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': label,
      'total': total,
      'exactExecuted': exactExecuted,
      'exactStopped': exactStopped,
      'wrongExecuted': wrongExecuted,
      'wrongStopped': wrongStopped,
      'wrongExecutedIds': wrongExecutedIds,
      'latencyMedianMicros': latencyMedianMicros,
      'latencyP95Micros': latencyP95Micros,
    };
  }
}

const int baselineVersion = 1;

const String _baselineNote =
    'Planchers releves sur la machine de developpement. '
    'La latence est une information, pas un seuil: elle depend du materiel. '
    'wrongExecuted est un plancher et non une cible: chaque identite de '
    'wrongExecutedIds est un defaut connu, pas une tolerance accordee.';

/// Reads the floors, failing loudly when the file is missing.
///
/// A missing baseline is not a passing baseline. The tests gate on it, so it is
/// better to stop and say so than to measure nothing and call it a green run.
RoutingBaseline loadBaseline(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Base de reference absente: $path. '
      'La generer avec dart run tool/voice_eval.dart --level routing --write-baseline',
    );
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError('Base de reference $path: objet JSON attendu');
  }
  return RoutingBaseline.from(decoded);
}

/// Writes the floors, so nobody edits the numbers by hand.
void writeBaseline(String path, RoutingBaseline baseline) {
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  File(path).writeAsStringSync('${encoder.convert(baseline.toJson())}\n');
}
