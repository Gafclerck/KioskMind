/// Compares what the phone heard with what the frozen set says was said.
///
/// Two rates are produced on purpose, and both travel in the result file. A
/// transcription that writes "2" where the reference says "deux" is not a
/// merchant mistake, and the parser of step 1a accepts both spellings, so folding
/// that difference away is not hiding a defect. Folding it away silently would
/// make the number unreadable, so the raw rate is measured alongside it.
library;

/// Puts two texts in the same shape before comparing them.
///
/// Lowercase, accents folded, apostrophes and punctuation turned into spaces,
/// whitespace collapsed. Splitting on the apostrophe is deliberate: it makes
/// "l'huile" and "l huile" land on the same tokens, and the apostrophe spelling is
/// the one a transcription is most likely to change.
List<String> comparisonWords(String text) {
  final StringBuffer buffer = StringBuffer();
  for (final int unit in _flatten(text).codeUnits) {
    final String? folded = _baseLetters[unit];
    if (folded != null) {
      buffer.write(folded);
    } else if (_keepAsIs(unit)) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write(' ');
    }
  }

  return buffer
      .toString()
      .split(' ')
      .map((String word) => _asNumberWord(word))
      .where((String word) => word.isNotEmpty)
      .toList();
}

/// Lowercase first, then the apostrophe variants reduced to the ASCII one. The
/// order matters: folding accents before lowercasing would miss the capital forms.
String _flatten(String text) {
  return text
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('ʼ', "'")
      .replaceAll('´', "'");
}

bool _keepAsIs(int unit) {
  final bool lower = unit >= 0x61 && unit <= 0x7A;
  final bool digit = unit >= 0x30 && unit <= 0x39;
  return lower || digit || unit == 0x20;
}

/// Every accented letter French uses, mapped to what a phone microphone hears
/// when nobody is being careful. All of them sit in Latin-1, so one code unit is
/// the whole character and the table can be indexed by code unit.
const Map<int, String> _baseLetters = <int, String>{
  0xE0: 'a', // a grave
  0xE1: 'a', // a acute
  0xE2: 'a', // a circumflex
  0xE3: 'a', // a tilde
  0xE4: 'a', // a diaeresis
  0xE5: 'a', // a ring
  0xE7: 'c', // c cedilla
  0xE8: 'e', // e grave
  0xE9: 'e', // e acute
  0xEA: 'e', // e circumflex
  0xEB: 'e', // e diaeresis
  0xEC: 'i', // i grave
  0xED: 'i', // i acute
  0xEE: 'i', // i circumflex
  0xEF: 'i', // i diaeresis
  0xF1: 'n', // n tilde
  0xF2: 'o', // o circumflex
  0xF3: 'o', // o tilde
  0xF4: 'o', // o acute
  0xF5: 'o', // o ring
  0xF6: 'o', // o diaeresis
  0xF9: 'u', // u grave
  0xFA: 'u', // u acute
  0xFB: 'u', // u circumflex
  0xFC: 'u', // u diaeresis
  0xFD: 'y', // y acute
  0xFF: 'y', // y diaeresis
  0x153: 'oe', // oe ligature
};

/// Single token numbers, which is all the reference set contains in one word.
/// A price like "cent cinquante" is two tokens and stays untouched: the point is
/// not to build the parser of step 1a here, only to stop the measurement from
/// punishing a transcription for a spelling the application accepts.
const Map<String, String> _numberWords = <String, String>{
  '0': 'zero',
  '1': 'un',
  '2': 'deux',
  '3': 'trois',
  '4': 'quatre',
  '5': 'cinq',
  '6': 'six',
  '7': 'sept',
  '8': 'huit',
  '9': 'neuf',
  '10': 'dix',
  '11': 'onze',
  '12': 'douze',
  '13': 'treize',
  '14': 'quatorze',
  '15': 'quinze',
  '16': 'seize',
  '17': 'dixsept',
  '18': 'dixhuit',
  '19': 'dixneuf',
  '20': 'vingt',
  '30': 'trente',
  '40': 'quarante',
  '50': 'cinquante',
  '60': 'soixante',
  '70': 'soixantedix',
  '80': 'quatrevingt',
  '90': 'quatrevingtdix',
  '100': 'cent',
  '1000': 'mille',
};

/// Both spellings collapse onto the digits, so the comparison survives whichever
/// side wrote the number in letters. A digit is already canonical and stays put.
String _asNumberWord(String word) {
  if (_numberWords.containsKey(word)) {
    return word;
  }
  return _reverseNumberWords[word] ?? word;
}

final Map<String, String> _reverseNumberWords = <String, String>{
  for (final MapEntry<String, String> entry in _numberWords.entries)
    entry.value: entry.key,
};

/// Word level error rate of one measured phrase.
final class WordErrorRate {
  const WordErrorRate({required this.errors, required this.referenceWords});

  /// Substitutions, insertions and deletions counted together.
  final int errors;

  final int referenceWords;

  /// A phrase with no reference word is fully wrong if anything was heard, and
  /// exact if nothing was: a rate dividing by zero would make the summary lie.
  double get ratio =>
      referenceWords == 0 ? (errors == 0 ? 0 : 1) : errors / referenceWords;

  @override
  String toString() =>
      '${(ratio * 100).toStringAsFixed(1)}% ($errors/$referenceWords mots)';
}

WordErrorRate wordErrorRate({
  required String reference,
  required String heard,
}) {
  return wordErrorRateOfWords(
    comparisonWords(reference),
    comparisonWords(heard),
  );
}

/// Words as they stand, lowercased and nothing else. This is the rate that shows
/// how different the two strings look, accents, punctuation and number spelling
/// included, so the folded rate can never be mistaken for the whole story.
List<String> literalWords(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList();
}

WordErrorRate wordErrorRateOfWords(List<String> reference, List<String> heard) {
  return WordErrorRate(
    errors: _editDistance(reference, heard),
    referenceWords: reference.length,
  );
}

/// Levenshtein distance over word lists, one rolling row so the memory cost stays
/// proportional to the shorter utterance.
int _editDistance(List<String> reference, List<String> heard) {
  List<int> previous = List<int>.filled(heard.length + 1, 0);
  for (int i = 0; i < heard.length; i++) {
    previous[i + 1] = i + 1;
  }
  for (int i = 1; i <= reference.length; i++) {
    final List<int> current = List<int>.filled(heard.length + 1, 0);
    current[0] = i;
    for (int j = 1; j <= heard.length; j++) {
      final int substitution =
          previous[j - 1] + (reference[i - 1] == heard[j - 1] ? 0 : 1);
      current[j] = _smallest(previous[j] + 1, current[j - 1] + 1, substitution);
    }
    previous = current;
  }
  return previous[heard.length];
}

int _smallest(int a, int b, int c) {
  int best = a;
  if (b < best) {
    best = b;
  }
  if (c < best) {
    best = c;
  }
  return best;
}
