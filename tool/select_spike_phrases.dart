import 'dart:convert';
import 'dart:io';

import 'validate_golden.dart' show textCasesPath;

/// Picks the 30 phrases the STT spike measures, and writes them where the spike
/// bundles them.
///
/// Why a tool and not a list typed by hand: the reference transcription of a
/// measured phrase has to be the exact utterance the frozen set holds, otherwise
/// the spike measures one thing and the routing metric later judges another. The
/// sample is a deterministic round robin over the eleven difficulty tags, so no
/// tag is drained before another is started, and `flutter test` re-runs the same
/// selection to catch the day the frozen set moves under the spike.
///
/// Usage:
///   dart run tool/select_spike_phrases.dart
const String spikePhrasesPath = 'spikes/stt_tts/assets/phrases.json';

/// The pipeline measures the spike on thirty phrases.
const int spikePhraseCount = 30;

/// Difficulty tags of the pipeline, section 11, in the order it lists them. The
/// order is the round robin order, so it is part of the contract of this tool.
const List<String> spikePhraseTags = <String>[
  'simple',
  'multi_items',
  'numbers_words',
  'numbers_digits',
  'price',
  'ambiguous_product',
  'missing_slot',
  'noise',
  'accent',
  'out_of_domain',
  'hard',
];

/// One phrase to speak, measured against the text the frozen set holds for it.
final class SpikePhrase {
  const SpikePhrase({required this.id, required this.text, required this.tags});

  factory SpikePhrase.fromCase(Map<String, Object?> entry) {
    final Object? tags = entry['tags'];
    if (tags is! List<Object?>) {
      throw FormatException('Cas ${entry['id']}: etiquettes attendue');
    }
    return SpikePhrase(
      id: entry['id']! as String,
      text: entry['utterance']! as String,
      tags: tags.cast<String>(),
    );
  }

  /// Identifier in the frozen set, so a measurement can be traced back to it.
  final String id;

  /// Displayed to the merchant and compared against the transcription.
  final String text;

  final List<String> tags;

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'text': text, 'tags': tags};
  }
}

/// Reads the phrases the spike bundles.
List<SpikePhrase> readSpikePhrases(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('Phrases du spike introuvables: $path');
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Fichier des phrases: objet JSON attendu');
  }
  final Object? phrases = decoded['phrases'];
  if (phrases is! List<Object?>) {
    throw const FormatException('Fichier des phrases: liste attendue');
  }
  return phrases
      .cast<Map<String, Object?>>()
      .map(
        (Map<String, Object?> entry) => SpikePhrase(
          id: entry['id']! as String,
          text: entry['text']! as String,
          tags: (entry['tags']! as List<Object?>).cast<String>(),
        ),
      )
      .toList();
}

/// One pass per tag, one case per tag and per pass.
///
/// Taking tag by tag in a single sweep would empty the rarest tag before the
/// second pass, and the spike would end up measuring only easy phrases. Rotating
/// instead costs nothing and keeps the spread honest.
List<SpikePhrase> selectSpikePhrases(
  Map<String, Object?> golden, {
  int count = spikePhraseCount,
}) {
  final Object? raw = golden['cases'];
  if (raw is! List<Object?>) {
    throw const FormatException('Jeu fige: liste de cas attendue');
  }
  final List<SpikePhrase> cases = <SpikePhrase>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) {
      continue;
    }
    final Object? tags = entry['tags'];
    if (tags is! List<Object?> ||
        !tags.cast<String>().any(spikePhraseTags.contains)) {
      continue;
    }
    cases.add(SpikePhrase.fromCase(entry));
  }
  if (cases.isEmpty) {
    throw StateError(
      'Aucun cas du jeu fige ne porte une etiquette du pipeline',
    );
  }
  if (cases.length < count) {
    throw StateError(
      'Jeu fige trop court: ${cases.length} cas pour $count demandes',
    );
  }

  final Map<String, List<SpikePhrase>> byTag = <String, List<SpikePhrase>>{
    for (final String tag in spikePhraseTags)
      tag: <SpikePhrase>[
        for (final SpikePhrase candidate in cases)
          if (candidate.tags.contains(tag)) candidate,
      ],
  };
  final Map<String, int> cursors = <String, int>{
    for (final String tag in spikePhraseTags) tag: 0,
  };
  final Set<String> taken = <String>{};
  final List<SpikePhrase> selected = <SpikePhrase>[];

  while (selected.length < count) {
    final int before = selected.length;
    for (final String tag in spikePhraseTags) {
      if (selected.length == count) {
        break;
      }
      final List<SpikePhrase> pool = byTag[tag]!;
      while (cursors[tag]! < pool.length &&
          taken.contains(pool[cursors[tag]!].id)) {
        cursors[tag] = cursors[tag]! + 1;
      }
      if (cursors[tag]! >= pool.length) {
        continue;
      }
      final SpikePhrase phrase = pool[cursors[tag]!];
      cursors[tag] = cursors[tag]! + 1;
      taken.add(phrase.id);
      selected.add(phrase);
    }
    if (selected.length == before) {
      throw StateError(
        'Volume demande ($count) superieur au nombre de cas distincts '
        'disponibles (${taken.length})',
      );
    }
  }
  return selected;
}

/// The asset the spike bundles, provenance included so a measured result can
/// always be traced to the set it came from.
String buildPhrasesAsset(List<SpikePhrase> phrases) {
  final Map<String, Object?> root = <String, Object?>{
    'version': 1,
    'source': textCasesPath,
    'count': phrases.length,
    'phrases': <Object?>[
      for (final SpikePhrase phrase in phrases) phrase.toJson(),
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
}

void main(List<String> arguments) {
  final List<SpikePhrase> selected = selectSpikePhrases(
    jsonDecode(File(textCasesPath).readAsStringSync()) as Map<String, Object?>,
  );
  final File target = File(spikePhrasesPath);
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(buildPhrasesAsset(selected));

  final Map<String, int> spread = <String, int>{
    for (final String tag in spikePhraseTags)
      tag: selected
          .where((SpikePhrase phrase) => phrase.tags.contains(tag))
          .length,
  };
  stdout.writeln('Ecrit: ${target.path}');
  stdout.writeln(
    'Etiquettes couvertes: ${spread.length}/${spikePhraseTags.length}',
  );
  stdout.writeln(
    spread.entries
        .map((MapEntry<String, int> e) => '${e.key}=${e.value}')
        .join(' '),
  );
}
