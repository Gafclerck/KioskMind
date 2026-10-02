import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_lexicon.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart'
    show kSupportedIntentIds;

import 'rule_parser_harness.dart';

/// Guards the marker tables against the frozen set.
///
/// A doubt marker is a word that makes a command unexecutable, so adding one is
/// not free: the word "hier" is a question in "annule la vente d'hier" and would
/// refuse a sale in "vendu deux riz hier". This file states, as an executable
/// rule, the property that was checked by hand when the tables were written: a
/// marker word never appears in a case that expects a routable outcome, once the
/// write-only exemption is applied.
void main() {
  final RuleParserHarness harness = RuleParserHarness();

  const Set<String> writeIntents = <String>{'record_sale', 'record_restock'};

  /// Every marker word, with the intents it actually applies to.
  ///
  /// A marker that applies to all intents makes any routable case containing it a
  /// collision. A write-only marker is legitimate in a routable question, because
  /// "reste" asks about a quantity in "combien il reste de riz" while it leaves
  /// the sale undetermined in "vendu le reste de sucre".
  final Map<String, Set<String>> appliesTo = <String, Set<String>>{
    for (final DoubtMarker marker in kDoubtMarkers)
      for (final String word in marker.words) word: kSupportedIntentIds,
    for (final Set<String> words in kWriteOnlyDoubtMarkers.values)
      for (final String word in words) word: writeIntents,
  };

  final List<Map<String, Object?>> cases = _frozenCases();

  test('le jeu fige est bien charge', () {
    expect(cases, isNotEmpty);
  });

  test('aucun marqueur ne casse un cas routable', () {
    final List<String> collisions = <String>[];

    for (final Map<String, Object?> testCase in cases) {
      final Map<String, Object?> expected =
          testCase['expected']! as Map<String, Object?>;
      if (expected['outcome'] != 'EXECUTE' &&
          expected['outcome'] != 'ASK_CONFIRMATION') {
        continue;
      }
      final List<String> tokens = harness.tokensOf(
        testCase['utterance']! as String,
      );
      final String? intent = expected['intent'] as String?;
      for (final MapEntry<String, Set<String>> entry in appliesTo.entries) {
        if (tokens.contains(entry.key) && entry.value.contains(intent)) {
          collisions.add(
            '${testCase['id']} "${testCase['utterance']}" '
            'contient "${entry.key}" et attend $intent',
          );
        }
      }
    }

    expect(collisions, isEmpty, reason: collisions.join('\n'));
  });

  group('tables elles-memes', () {
    test('aucun mot n est dans deux groupes a la fois', () {
      final Set<String> seen = <String>{};
      final List<String> twice = <String>[];

      for (final Set<String> group in <Set<String>>[
        kDestructiveWords,
        kUnboundedWords,
        kOrderWords,
        kPriceQuestionWords,
        kCorrectionWords,
        kAnaphoraWords,
        kRelativeQuantityWords,
        kRestRelativeQuantityWords,
        kQuantityBridges,
        kUnitWords,
        kCurrencyWords,
      ]) {
        for (final String word in group) {
          if (!seen.add(word)) {
            twice.add(word);
          }
        }
      }

      expect(twice, isEmpty, reason: twice.join(', '));
    });

    test('aucun mot n est vide ni accentue', () {
      final List<String> suspect = <String>[];
      for (final Set<String> group in <Set<String>>[
        kDestructiveWords,
        kPriceQuestionWords,
        kCorrectionWords,
        kAnaphoraWords,
        kUnitWords,
      ]) {
        for (final String word in group) {
          if (word.isEmpty || word != word.toLowerCase()) {
            suspect.add(word);
          }
          if (RegExp('[^a-z]').hasMatch(word)) {
            suspect.add(word);
          }
        }
      }

      expect(suspect, isEmpty, reason: suspect.join(', '));
    });

    test('"demi" n est pas une unite', () {
      // "un demi sac de riz" vaut 0,5: si "demi" etait un pont, le compte
      // chercherait plus loin et la ligne perdrait sa valeur.
      expect(kUnitWords, isNot(contains('demi')));
    });
  });
}

List<Map<String, Object?>> _frozenCases() {
  final Map<String, Object?> decoded =
      jsonDecode(File('voice/golden/text_cases.json').readAsStringSync())
          as Map<String, Object?>;
  return <Map<String, Object?>>[
    for (final Object? entry in decoded['cases']! as List<Object?>)
      entry! as Map<String, Object?>,
  ];
}
