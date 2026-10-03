import 'dart:convert';
import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/item_list_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/canonical_arguments.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';

import 'routing_cases.dart';
import 'routing_harness.dart';
import 'routing_metrics.dart' as routing_metrics;

/// Measures the pipeline against the frozen sets.
///
/// Usage:
///   dart run tool/voice_eval.dart --level text            scores and lists misses
///   dart run tool/voice_eval.dart --level text --show 20  shows 20 misses
///   dart run tool/voice_eval.dart --level text --cases t001,t042
///   dart run tool/voice_eval.dart --level routing         scores the whole pipeline
///   dart run tool/voice_eval.dart --level routing --cases t001,t042
///   dart run tool/voice_eval.dart --level routing --transcripts
///                                                        adds the 44 reference
///                                                        transcripts, scored
///                                                        separately
///   dart run tool/voice_eval.dart --level routing --write-baseline
///                                                        records the floors
///
/// `--audio` is accepted as the old name of `--transcripts`.
///
/// The routing level prints four counts, and they are sorted by what the pipeline
/// did rather than by how often it was right: **wrong routing executed** comes
/// first, because a sale recorded without confirmation is the failure the module
/// exists to prevent, and it is the one a single "percent exact" hides. The two
/// sets are never added together: the 44 reference transcripts are scored on
/// their words, with no recognizer and no recording, so merging them with the
/// 266 text cases would credit the pipeline with an audio result it has not
/// been given.
///
/// What "exact parsing" means here, stated once so the number cannot drift:
///
///  * a case that expects a handler call is exact when the proposal carries the
///    expected intent and the expected arguments, the quantity and the product
///    identifier included. The doubts it also carries are not held against it:
///    deciding what to do with them is the policy's work, measured in 1b;
///  * a case that expects no call is exact when the proposal is not routable, that
///    is when it carries at least one doubt.
///
/// The outcome shown next to each miss is the one the 1a parser supports. The
/// decision policy of 1b will replace it, which is why the confirmation cases
/// already count as parsed when their intent and arguments match.
///
/// What "exact routing" means is written once, in `routing_cases.dart`, and the
/// tool, the routing test and the baseline test share it, so no two of them can
/// report different numbers for the same code.
const String catalogFixturePath = 'voice/golden/catalog_fixture.json';
const String intentCatalogPath = 'voice/intent_catalog.json';

/// Doubts that mean the command is refused rather than questioned.
///
/// Provisional for 1a: it only has to be faithful enough to tell a refusal from a
/// question while measuring parsing. The decision policy in 1b owns this table.
const Set<DoubtKind> kRefusingDoubts = <DoubtKind>{
  DoubtKind.destructiveRequest,
  DoubtKind.noOrderUseCase,
  DoubtKind.unboundedScope,
  DoubtKind.outOfDomain,
  DoubtKind.archivedProduct,
  DoubtKind.invalidQuantity,
};

void main(List<String> arguments) {
  final int show = _intOption(arguments, '--show') ?? 20;
  final List<String>? only = _casesOption(arguments);
  final String level = _option(arguments, '--level') ?? 'text';
  final bool shouldWriteBaseline = _flag(arguments, '--write-baseline');

  switch (level) {
    case 'text':
      if (shouldWriteBaseline) {
        throw StateError('--write-baseline ne vaut que pour le niveau routing');
      }
      _scoreText(show: show, only: only);
    case 'routing':
      _scoreRouting(
        show: show,
        only: only,
        reference:
            _flag(arguments, '--transcripts') || _flag(arguments, '--audio'),
        writeBaseline: shouldWriteBaseline,
      );
    default:
      throw StateError('Niveau inconnu: $level (attendu: text ou routing)');
  }
}

/// Scores the rule parser alone, as step 1a measured it.
///
/// The three routing measures do not apply here: nothing is executed at this
/// level, so there is no wrong execution to count. The parse latency is reported
/// all the same, since it is the T1 parser being timed.
void _scoreText({required int show, required List<String>? only}) {
  final List<_Case> cases = _loadCases(routing_metrics.textSetPath);
  final List<_Case> selected = <_Case>[
    if (only == null)
      for (final _Case c in cases) c
    else
      for (final _Case c in cases)
        if (only.contains(c.id)) c,
  ];

  final RuleBasedParser parser = _buildParser();
  final List<int> latencies = <int>[];
  final List<_Miss> misses = <_Miss>[];
  for (final _Case testCase in selected) {
    final Stopwatch watch = Stopwatch()..start();
    final CommandProposal proposal = parser.parse(testCase.utterance);
    watch.stop();
    latencies.add(watch.elapsedMicroseconds);
    final _Verdict verdict = _judge(testCase, proposal);
    if (!verdict.exact) {
      misses.add(
        _Miss(testCase: testCase, proposal: proposal, verdict: verdict),
      );
    }
  }

  final int exact = selected.length - misses.length;
  stdout.writeln(
    'voice_eval niveau texte : $exact/${selected.length} exact '
    '(${(exact / selected.length * 100).toStringAsFixed(1)} %)',
  );
  stdout.writeln(
    '  appels de handler attendus : '
    '${selected.where((_Case c) => c.expectsCall).length}',
  );
  stdout.writeln(
    '  refus ou questions attendus : '
    '${selected.where((_Case c) => !c.expectsCall).length}',
  );
  stdout.writeln(
    '  latence du parseur T1 : mediane ${_ms(latencies, 0.5)}, '
    'p95 ${_ms(latencies, 0.95)} (cette machine, pas une cible)',
  );

  for (final _Miss miss in misses.take(show)) {
    stdout.writeln('');
    stdout.writeln('  ${miss.testCase.id} "${miss.testCase.utterance}"');
    stdout.writeln('    attendu : ${miss.verdict.expected}');
    stdout.writeln('    obtenu  : ${miss.verdict.actual}');
  }
  if (misses.length > show) {
    stdout.writeln('');
    stdout.writeln('  ... ${misses.length - show} autres');
  }
  if (misses.isNotEmpty) {
    exitCode = 1;
  }
}

/// Scores the whole pipeline: parse, decide, execute, and record the call.
///
/// The two sets are scored separately and never added together. The 44
/// reference transcripts are read from their `groundTruthTranscript`, so no
/// recognizer has run on them and no recording exists: they measure routing on
/// hard words, not audio.
Future<void> _scoreRouting({
  required int show,
  required List<String>? only,
  required bool reference,
  required bool writeBaseline,
}) async {
  final RoutingHarness harness = RoutingHarness();
  final List<routing_metrics.RoutingScore> scores =
      <routing_metrics.RoutingScore>[
        await routing_metrics.scoreSet(
          label: routing_metrics.textSetLabel,
          cases: _selected(loadFrozenCases(routing_metrics.textSetPath), only),
          harness: harness,
        ),
        if (reference)
          await routing_metrics.scoreSet(
            label: routing_metrics.referenceSetLabel,
            cases: _selected(
              loadFrozenCases(routing_metrics.referenceSetPath),
              only,
            ),
            harness: harness,
          ),
      ];

  for (final routing_metrics.RoutingScore score in scores) {
    _printScore(score, show: show);
  }
  if (writeBaseline) {
    routing_metrics.writeBaseline(
      routing_metrics.baselinePath,
      routing_metrics.RoutingBaseline.of(scores),
    );
    stdout.writeln('');
    stdout.writeln(
      'base de reference ecrite : ${routing_metrics.baselinePath}',
    );
  }
  if (scores.any((routing_metrics.RoutingScore s) => s.exact != s.total)) {
    exitCode = 1;
  }
}

/// Prints one set, the dangerous count first.
void _printScore(routing_metrics.RoutingScore score, {required int show}) {
  stdout.writeln('');
  stdout.writeln('=== jeu ${score.label} : ${score.total} cas ===');
  if (score.casesWithRecording > 0) {
    stdout.writeln(
      '  ${score.casesWithRecording} cas ecrits a partir d un enregistrement, '
      '${score.recordingsPresent} enregistrement present sur disque',
    );
    stdout.writeln(
      '  aucun moteur de reconnaissance vocale n a tourne ici : '
      'ceci mesure le texte de reference, pas une performance audio',
    );
  }
  stdout.writeln(
    'mauvais routage execute : ${score.wrongExecuted}/${score.total} '
    '(${_rate(score.wrongExecuted, score.total)})  <- le chiffre qui compte',
  );
  for (final routing_metrics.ScoredCase c in score.wrongExecutedCases) {
    stdout.writeln('  ${c.id} "${c.utterance}"');
    stdout.writeln('    attendu : ${c.expected}');
    stdout.writeln('    obtenu  : ${c.actual}');
  }
  stdout.writeln(
    'routage exact execute : ${score.exactExecuted}/${score.total} '
    '(${_rate(score.exactExecuted, score.total)})',
  );
  stdout.writeln(
    'clarifie ou refuse    : ${score.exactStopped}/${score.total} '
    '(${_rate(score.exactStopped, score.total)})',
  );
  stdout.writeln(
    'arret incorrect       : ${score.wrongStopped}/${score.total} '
    '(${_rate(score.wrongStopped, score.total)})',
  );
  stdout.writeln(
    'latence du parseur T1 : mediane ${_duration(score.medianLatency)}, '
    'p95 ${_duration(score.p95Latency)} (cette machine, pas une cible)',
  );

  final List<routing_metrics.ScoredCase> stopped = score.wrongStoppedCases;
  for (final routing_metrics.ScoredCase c in stopped.take(show)) {
    stdout.writeln('');
    stdout.writeln('  ${c.id} "${c.utterance}"');
    stdout.writeln('    attendu : ${c.expected}');
    stdout.writeln('    obtenu  : ${c.actual}');
  }
  if (stopped.length > show) {
    stdout.writeln('');
    stdout.writeln('  ... ${stopped.length - show} autres arrets incorrects');
  }
}

List<FrozenCase> _selected(List<FrozenCase> cases, List<String>? only) {
  if (only == null) {
    return cases;
  }
  return <FrozenCase>[
    for (final FrozenCase c in cases)
      if (only.contains(c.id)) c,
  ];
}

String _rate(int part, int total) =>
    total == 0 ? '-' : '${(part / total * 100).toStringAsFixed(1)} %';

String _duration(Duration value) =>
    _ms(List<int>.of(<int>[value.inMicroseconds]), 0.5);

/// Nearest-rank percentile over parse latencies, in milliseconds.
String _ms(List<int> micros, double fraction) {
  if (micros.isEmpty) {
    return '-';
  }
  final List<int> sorted = List<int>.of(micros)..sort();
  final int index = (fraction * sorted.length).ceil() - 1;
  final double millis =
      sorted[index.clamp(0, sorted.length - 1)] /
      Duration.microsecondsPerMillisecond;
  return '${millis.toStringAsFixed(2).replaceAll('.', ',')} ms';
}

/// The parser under test, wired exactly as the app will wire it.
RuleBasedParser _buildParser() {
  const VoiceConfig config = VoiceConfig();
  final TextNormalizer normalizer = TextNormalizer(fillers: config.fillers);
  final IntentCatalog catalog = parseIntentCatalog(
    File(intentCatalogPath).readAsStringSync(),
  );
  return RuleBasedParser(
    normalizer: normalizer,
    detector: IntentDetector(catalog: catalog, normalizer: normalizer),
    items: ItemListExtractor(
      resolver: ProductResolver(
        products: parseCatalogFixture(
          File(catalogFixturePath).readAsStringSync(),
        ),
        config: config,
        normalizer: normalizer,
      ),
      lines: LineExtractor(numbers: const FrenchNumberParser(), config: config),
    ),
    config: config,
  );
}

/// Whether the proposal is exactly what the case expects.
_Verdict _judge(_Case testCase, CommandProposal proposal) {
  final String actual = testCase.expectsCall
      ? _routedSummary(proposal)
      : _doubtSummary(proposal);
  final bool exact = testCase.expectsCall
      ? _argumentsMatch(testCase, proposal)
      : !proposal.isComplete;
  return _Verdict(
    expected: testCase.expectsCall
        ? '${testCase.intent} ${jsonEncode(canonicalArguments(_expectedArgs(testCase)))}'
        : 'non routable',
    actual: actual,
    exact: exact,
  );
}

Map<String, Object?> _expectedArgs(_Case testCase) {
  final Object? raw = testCase.rawExpected['handlerArgs'];
  if (raw is! Map<String, Object?>) {
    return const <String, Object?>{};
  }
  return raw;
}

/// The proposal projected the way the handler would be called.
String _routedSummary(CommandProposal proposal) {
  return '${proposal.intentId} ${jsonEncode(proposalArguments(proposal))}';
}

String _doubtSummary(CommandProposal proposal) {
  if (proposal.doubts.isEmpty) {
    return 'routable ${proposal.intentId} '
        '${jsonEncode(proposalArguments(proposal))}';
  }
  return 'doutes: '
      '${proposal.doubts.map((Doubt d) => d.kind.name).toList().join(',')}';
}

bool _argumentsMatch(_Case testCase, CommandProposal proposal) {
  if (proposal.intentId != testCase.intent) {
    return false;
  }
  return jsonEncode(proposalArguments(proposal)) ==
      jsonEncode(canonicalArguments(_expectedArgs(testCase)));
}

/// Projects a proposal onto the argument map the call journal records.
///
/// The two shapes are the ones the intent inputs define: an item list for a sale
/// and a restock, a single product for a question, the session sale for a
/// cancellation. A spoken amount is part of a restock only.
Map<String, Object?> proposalArguments(CommandProposal proposal) {
  final List<ItemMention>? items = proposal.valueOf<List<ItemMention>>('items');
  if (items != null) {
    return canonicalArguments(<String, Object?>{
      'items': <Object?>[
        for (final ItemMention line in items)
          line.toArguments(proposal.intentId),
      ],
    });
  }
  final String? productId = proposal.valueOf<String>('productId');
  if (productId != null) {
    return <String, Object?>{'productId': productId};
  }
  final String? saleId = proposal.valueOf<String>('saleId');
  if (saleId != null) {
    return <String, Object?>{'saleId': saleId};
  }
  return const <String, Object?>{};
}

List<_Case> _loadCases(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('Jeu de cas introuvable: $path');
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError('Jeu de cas: objet JSON attendu');
  }
  final Object? raw = decoded['cases'];
  if (raw is! List<Object?>) {
    throw StateError('Jeu de cas: "cases" doit etre une liste');
  }
  return <_Case>[
    for (final Object? entry in raw)
      if (entry is Map<String, Object?>) _Case.from(entry),
  ];
}

int? _intOption(List<String> arguments, String name) {
  for (int index = 0; index < arguments.length - 1; index++) {
    if (arguments[index] == name) {
      return int.tryParse(arguments[index + 1]);
    }
  }
  return null;
}

String? _option(List<String> arguments, String name) {
  for (int index = 0; index < arguments.length - 1; index++) {
    if (arguments[index] == name) {
      return arguments[index + 1];
    }
  }
  return null;
}

bool _flag(List<String> arguments, String name) => arguments.contains(name);

List<String>? _casesOption(List<String> arguments) {
  for (int index = 0; index < arguments.length - 1; index++) {
    if (arguments[index] == '--cases') {
      return arguments[index + 1].split(',');
    }
  }
  return null;
}

/// One expected behaviour from the frozen set.
final class _Case {
  const _Case({
    required this.id,
    required this.utterance,
    required this.expectedOutcome,
    required this.intent,
    required this.rawExpected,
  });

  factory _Case.from(Map<String, Object?> json) {
    final Object? rawExpected = json['expected'];
    if (rawExpected is! Map<String, Object?>) {
      throw StateError('Cas ${json['id']}: "expected" manquant');
    }
    return _Case(
      id: json['id']! as String,
      utterance: json['utterance']! as String,
      expectedOutcome: rawExpected['outcome']! as String,
      intent: rawExpected['intent'] as String?,
      rawExpected: rawExpected,
    );
  }

  final String id;
  final String utterance;
  final String expectedOutcome;
  final String? intent;
  final Map<String, Object?> rawExpected;

  /// Whether the first turn is expected to reach a handler.
  ///
  /// A case whose expectation carries a `then` asks a question first, so the
  /// parser is judged on the doubt, not on a call.
  bool get expectsCall => rawExpected.containsKey('handlerArgs');
}

final class _Verdict {
  const _Verdict({
    required this.expected,
    required this.actual,
    required this.exact,
  });

  final String expected;
  final String actual;
  final bool exact;
}

final class _Miss {
  const _Miss({
    required this.testCase,
    required this.proposal,
    required this.verdict,
  });

  final _Case testCase;
  final CommandProposal proposal;
  final _Verdict verdict;
}
