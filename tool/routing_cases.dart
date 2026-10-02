import 'dart:convert';
import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/handlers/canonical_arguments.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';

import 'routing_harness.dart';

/// The frozen set as the routing metric reads it, and the comparison it makes.
///
/// The model and the judge live here, not in the test and not in `voice_eval`, so
/// the percentage the tool prints and the percentage the test asserts come from one
/// piece of code and cannot drift apart.
///
/// A case is judged on two things, and both are stated by the case itself:
///  * the issue of the **first** turn, since that is the one the merchant sees. A
///    case that expects a clarification is not failed by the call that answer
///    produces;
///  * the call that was made, expected at `expected.handlerArgs` or at
///    `expected.then.handlerArgs`, whichever the case states.

/// One answer of the frozen set, already resolved.
typedef AnsweredSlot = ({String slot, Object? value});

/// The call a case expects, whether on the first turn or after its answers.
typedef ExpectedCall = ({String intent, Map<String, Object?> handlerArgs});

/// One frozen case, read the way the routing metric reads it.
final class FrozenCase {
  const FrozenCase({
    required this.id,
    required this.utterance,
    required this.firstOutcome,
    required this.callExpected,
    required this.answers,
  });

  factory FrozenCase.from(Map<String, Object?> json) {
    final Map<String, Object?> expected =
        json['expected']! as Map<String, Object?>;
    final Map<String, Object?> then =
        expected['then'] as Map<String, Object?>? ?? expected;
    return FrozenCase(
      id: json['id']! as String,
      // An audio case states what the recording says; both files then measure the
      // same routing on the same words. The transcription a real recognizer
      // produces is measured by `voice_eval --transcripts`, not here.
      utterance:
          (json['utterance'] ?? json['groundTruthTranscript'])! as String,
      firstOutcome: expected['outcome']! as String,
      callExpected: _callOf(then),
      answers: _answersOf(expected),
    );
  }

  static ExpectedCall? _callOf(Map<String, Object?> node) {
    final Object? intent = node['intent'];
    final Object? args = node['handlerArgs'];
    if (intent is! String || args is! Map<String, Object?>) {
      return null;
    }
    return (intent: intent, handlerArgs: args);
  }

  static List<AnsweredSlot> _answersOf(Map<String, Object?> node) {
    final Object? raw = node['resolution'];
    if (raw is! List<Object?>) {
      return const <AnsweredSlot>[];
    }
    return <AnsweredSlot>[
      for (final Object? entry in raw)
        if (entry is Map<String, Object?>)
          (slot: entry['slot']! as String, value: entry['value']),
    ];
  }

  final String id;
  final String utterance;
  final String firstOutcome;
  final ExpectedCall? callExpected;
  final List<AnsweredSlot> answers;

  /// Whether the case cancels the last sale, and so needs a session that recorded
  /// one before the utterance.
  bool get undoesASale =>
      callExpected?.intent == 'cancel_last_sale' &&
      callExpected!.handlerArgs.values.contains(kLastSaleIdPlaceholder);
}

/// Reads a frozen set of cases.
List<FrozenCase> loadFrozenCases(String path) {
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
  return <FrozenCase>[
    for (final Object? entry in raw)
      if (entry is Map<String, Object?>) FrozenCase.from(entry),
  ];
}

/// Compares one route with what its case expects.
RouteVerdict judge(FrozenCase testCase, Route route, String? primedSaleId) {
  final String expected = jsonEncode(<String, Object?>{
    'outcome': testCase.firstOutcome,
    if (testCase.callExpected != null) 'intent': testCase.callExpected!.intent,
    if (testCase.callExpected != null)
      'handlerArgs': _withSessionSaleId(
        canonicalArguments(testCase.callExpected!.handlerArgs),
        primedSaleId,
      ),
  });
  final String actual = jsonEncode(<String, Object?>{
    'outcome': route.firstOutcome,
    if (route.call != null) 'intent': route.call!.intentId,
    if (route.call != null) 'handlerArgs': route.call!.handlerArgs,
  });
  return RouteVerdict(
    expected: expected,
    actual: actual,
    exact: expected == actual,
  );
}

/// Replaces the placeholder by the id the session recorded.
///
/// A case that cancels states the sale it undoes as [kLastSaleIdPlaceholder]: the
/// handler is compared on the id the session actually recorded, since the harness
/// chose that sale and the frozen case deliberately did not name one.
Object? _withSessionSaleId(Object? value, String? primedSaleId) {
  if (value == kLastSaleIdPlaceholder) {
    return primedSaleId;
  }
  if (value is List<Object?>) {
    return <Object?>[
      for (final Object? entry in value)
        _withSessionSaleId(entry, primedSaleId),
    ];
  }
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in value.entries)
        entry.key: _withSessionSaleId(entry.value, primedSaleId),
    };
  }
  return value;
}

/// The two sides of one comparison.
final class RouteVerdict {
  const RouteVerdict({
    required this.expected,
    required this.actual,
    required this.exact,
  });

  final String expected;
  final String actual;
  final bool exact;
}
