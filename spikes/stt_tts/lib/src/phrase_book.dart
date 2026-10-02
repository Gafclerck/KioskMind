import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One phrase the merchant speaks, straight from the frozen set.
final class SpikePhrase {
  const SpikePhrase({required this.id, required this.text, required this.tags});

  final String id;
  final String text;
  final List<String> tags;

  @override
  String toString() => '$id: $text';
}

/// The thirty phrases the spike measures, bundled as an asset by
/// `tool/select_spike_phrases.dart`.
final class PhraseBook {
  const PhraseBook({required this.source, required this.phrases});

  /// The frozen set this sample was taken from, kept in the asset so a result can
  /// always be traced back to it.
  final String source;

  final List<SpikePhrase> phrases;
}

/// Decoding is separated from loading so it can be tested without a bundle.
PhraseBook decodePhraseBook(String content) {
  final Object? decoded = jsonDecode(content);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Phrases du spike: objet JSON attendu');
  }
  final Object? raw = decoded['phrases'];
  if (raw is! List<Object?>) {
    throw const FormatException('Phrases du spike: liste attendue');
  }
  return PhraseBook(
    source: (decoded['source'] as String?) ?? 'inconnue',
    phrases: raw.map(_phrase).toList(),
  );
}

SpikePhrase _phrase(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const FormatException('Phrases du spike: objet attendu');
  }
  final Object? tags = entry['tags'];
  return SpikePhrase(
    id: entry['id']! as String,
    text: entry['text']! as String,
    tags: tags is List<Object?> ? tags.cast<String>() : const <String>[],
  );
}

Future<PhraseBook> loadPhraseBook({String asset = spikePhrasesAsset}) async {
  return decodePhraseBook(await rootBundle.loadString(asset));
}

const String spikePhrasesAsset = 'assets/phrases.json';
