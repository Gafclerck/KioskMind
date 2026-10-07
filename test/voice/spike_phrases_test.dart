import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/select_spike_phrases.dart';
import '../../tool/validate_golden.dart' show textCasesPath;

/// The 30 phrases the STT spike measures must be a deterministic sample of the
/// frozen set, not a list typed by hand. Two reasons: the reference transcription
/// is then the exact utterance the routing metric will later compare against, and
/// a sample chosen today cannot quietly drift away from the set it claims to
/// come from.
void main() {
  group('le tirage', () {
    test('couvre les 11 etiquettes de difficulte du pipeline', () {
      final List<SpikePhrase> selected = selectSpikePhrases(
        _synthetic(),
        count: 11,
      );

      expect(
        selected.expand((SpikePhrase phrase) => phrase.tags).toSet(),
        containsAll(spikePhraseTags),
      );
    });

    test('ne retient jamais le meme cas deux fois', () {
      final List<SpikePhrase> selected = selectSpikePhrases(
        _synthetic(),
        count: 30,
      );

      expect(
        selected.map((SpikePhrase phrase) => phrase.id).toSet().length,
        30,
      );
    });

    test(
      'chaque phrase retenue porte une etiquette de la liste du pipeline',
      () {
        final List<SpikePhrase> selected = selectSpikePhrases(
          _synthetic(),
          count: 20,
        );

        for (final SpikePhrase phrase in selected) {
          expect(phrase.tags, isNotEmpty, reason: phrase.id);
          expect(
            phrase.tags.every(spikePhraseTags.contains),
            isTrue,
            reason: phrase.id,
          );
        }
      },
    );

    test('respecte le volume demande', () {
      expect(selectSpikePhrases(_synthetic(), count: 30).length, 30);
    });

    test('est deterministe: deux tirages du meme jeu sont identiques', () {
      final Map<String, Object?> golden = _synthetic();

      final List<SpikePhrase> first = selectSpikePhrases(golden, count: 30);
      final List<SpikePhrase> second = selectSpikePhrases(golden, count: 30);

      expect(
        first.map((SpikePhrase phrase) => phrase.id).toList(),
        second.map((SpikePhrase phrase) => phrase.id).toList(),
      );
    });

    test('repartit les volumes plutot que de vider les etiquettes rares', () {
      // 11 tours de table, un cas par etiquette et par tour: chaque etiquette
      // rare est prise avant qu'une etiquette abondante n'ait fini son lot.
      final List<SpikePhrase> selected = selectSpikePhrases(
        _synthetic(),
        count: 11,
      );

      expect(selected.length, 11);
      expect(
        selected.map((SpikePhrase phrase) => phrase.tags.first).toSet().length,
        11,
      );
    });

    test('refuse un volume que le jeu ne peut pas fournir', () {
      expect(
        () => selectSpikePhrases(_synthetic(), count: 10_000),
        throwsA(isA<StateError>()),
      );
    });

    test('refuse un jeu sans aucune etiquette connue', () {
      final Map<String, Object?> golden = <String, Object?>{
        'cases': <Object?>[
          <String, Object?>{
            'id': 'x1',
            'utterance': 'bonjour',
            'tags': <String>['mystery'],
          },
        ],
      };

      expect(
        () => selectSpikePhrases(golden, count: 1),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('le fichier livre', () {
    late List<SpikePhrase> committed;

    setUpAll(() {
      committed = readSpikePhrases(spikePhrasesPath);
    });

    test('existe et contient le volume demande par le pipeline', () {
      expect(committed.length, spikePhraseCount);
      expect(spikePhraseCount, 30);
    });

    test('correspond exactement a un tirage frais sur le jeu fige', () {
      // Le garde-fou de derive: si le jeu fige change apres le tag, ce test
      // echoue au lieu de laisser le spike mesurer l'ancien jeu.
      final List<SpikePhrase> fresh = selectSpikePhrases(
        _golden(),
        count: spikePhraseCount,
      );

      expect(_ids(committed), _ids(fresh));
    });

    test('chaque phrase existe toujours, au meme texte, dans le jeu fige', () {
      final Map<String, Object?> byId = <String, Object?>{
        for (final Object? entry in _golden()['cases']! as List<Object?>)
          (entry! as Map<String, Object?>)['id']! as String: entry,
      };

      for (final SpikePhrase phrase in committed) {
        final Object? origin = byId[phrase.id];
        expect(
          origin,
          isNotNull,
          reason: 'cas sorti du jeu fige: ${phrase.id}',
        );
        expect(
          (origin! as Map<String, Object?>)['utterance'],
          phrase.text,
          reason: phrase.id,
        );
      }
    });

    test('couvre les 11 etiquettes de difficulte', () {
      expect(
        committed.expand((SpikePhrase phrase) => phrase.tags).toSet(),
        containsAll(spikePhraseTags),
      );
    });

    test('chaque phrase est prononcable: ni vide, ni marqueur de jeu', () {
      for (final SpikePhrase phrase in committed) {
        expect(phrase.text.trim(), isNotEmpty, reason: phrase.id);
        expect(phrase.text, isNot(contains(r'$')), reason: phrase.id);
      }
    });
  });
}

List<String> _ids(List<SpikePhrase> phrases) {
  return phrases
      .map((SpikePhrase phrase) => '${phrase.id}|${phrase.text}')
      .toList();
}

Map<String, Object?> _golden() {
  return jsonDecode(File(textCasesPath).readAsStringSync())
      as Map<String, Object?>;
}

/// A stand-in for the frozen set: one case per tag is the minimum the round robin
/// can work with, plus a long tail on one tag to prove the rotation does not
/// simply take the most numerous tag first.
Map<String, Object?> _synthetic() {
  final List<Object?> cases = <Object?>[];
  int counter = 0;
  for (final String tag in spikePhraseTags) {
    cases.add(_case('t${counter++}', 'phrase $tag', <String>[tag]));
  }
  for (int i = 0; i < 50; i++) {
    cases.add(
      _case('t${counter++}', 'phrase simple $i', <String>['simple', 'hard']),
    );
  }
  return <String, Object?>{'cases': cases};
}

Map<String, Object?> _case(String id, String utterance, List<String> tags) {
  return <String, Object?>{
    'id': id,
    'utterance': utterance,
    'expected': <String, Object?>{'outcome': 'EXECUTE'},
    'tags': tags,
    'notes': '',
  };
}
