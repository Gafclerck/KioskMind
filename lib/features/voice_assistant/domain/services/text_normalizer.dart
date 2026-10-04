import '../entities/voice_config.dart';

/// Text ready to be matched: a flat token list plus the same content as a string.
final class NormalizedText {
  const NormalizedText({required this.tokens});

  /// Accent-free lowercase words, in spoken order.
  final List<String> tokens;

  /// The tokens joined by a single space, for trigger matching.
  String get text => tokens.join(' ');

  bool get isEmpty => tokens.isEmpty;

  int get length => tokens.length;

  /// The tokens from [start] to [start + count] joined by a space.
  String span(int start, int count) => tokens.skip(start).take(count).join(' ');

  @override
  String toString() => text;
}

/// Turns a speech-recognition transcript into tokens a rule parser can match.
///
/// The transcript is untrusted input, so this is also where the surface noise a
/// recognizer leaves behind is removed. Every step is a pure string operation:
/// the same transcript always yields the same tokens, which is what makes the
/// golden set reproducible.
final class TextNormalizer {
  const TextNormalizer({this.fillers = kVoiceFillers});

  /// Tokens dropped wherever they appear. They carry no meaning for any intent,
  /// so removing them cannot change a routing decision.
  final Set<String> fillers;

  /// Accent folding for the Latin letters French uses. A data table rather than a
  /// range check, so a new character is added by reading this list.
  static const Map<String, String> _accents = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'æ': 'ae',
    'ç': 'c',
    'ć': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ß': 'ss',
  };

  /// Anything that is neither a letter nor a digit separates words, so a stray
  /// symbol cannot glue two words together.
  static bool _isLetter(String character) {
    final int code = character.codeUnitAt(0);
    return (code >= 0x61 && code <= 0x7a) || code >= 0xe0;
  }

  static bool _isDigit(String character) {
    final int code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isDecimalMark(String character) =>
      character == '.' || character == ',';

  NormalizedText normalize(String raw) {
    final String lowered = raw.toLowerCase();
    final List<String> tokens = <String>[];
    final StringBuffer word = StringBuffer();

    void endWord() {
      if (word.isEmpty) {
        return;
      }
      tokens.add(word.toString());
      word.clear();
    }

    for (int i = 0; i < lowered.length; i++) {
      final String character = lowered[i];

      if (character == "'" || character == '\u2019') {
        _resolveElision(word, tokens);
        continue;
      }
      if (_isDigit(character)) {
        endWord();
        final _Number number = _readNumber(lowered, i);
        tokens.add(number.text);
        i = number.lastIndex - 1;
        continue;
      }
      final String? accent = _accents[character];
      if (accent != null) {
        word.write(accent);
        continue;
      }
      if (_isLetter(character)) {
        word.write(character);
        continue;
      }
      endWord();
    }
    endWord();

    return NormalizedText(
      tokens: <String>[
        for (final String t in tokens)
          if (!fillers.contains(t)) t,
      ],
    );
  }

  /// Handles the apostrophe that ends the word being read.
  ///
  /// French elision means the determiner itself is absent from what was said:
  /// "d'un" announces one unit, "de l'eau" announces no quantity at all. The
  /// determiner and a "de" standing in front of it are consumed here rather than
  /// matched later. Any other apostrophe joins a contraction such as "j'ai", so
  /// nothing is inserted.
  static void _resolveElision(StringBuffer word, List<String> tokens) {
    final String written = word.toString();
    if (written.endsWith('l') && _dropPrecedingDe(tokens)) {
      word.clear();
      return;
    }
    if (written.endsWith('d')) {
      word
        ..clear()
        ..write(written.substring(0, written.length - 1));
    }
  }

  /// Removes the "de" of "de l'" when it is the last token read. "de" further
  /// back belongs to the sentence, not to the elision, and stays.
  static bool _dropPrecedingDe(List<String> tokens) {
    if (tokens.isNotEmpty && tokens.last == 'de') {
      tokens.removeLast();
      return true;
    }
    return false;
  }

  /// Reads the number starting at [start], keeping a single decimal mark so
  /// "4,5" stays four and a half rather than four followed by five.
  static _Number _readNumber(String raw, int start) {
    final StringBuffer number = StringBuffer(raw[start]);
    int cursor = start + 1;
    while (cursor < raw.length) {
      final String next = raw[cursor];
      if (_isDigit(next)) {
        number.write(next);
        cursor++;
      } else if (_isDecimalMark(next) &&
          cursor + 1 < raw.length &&
          _isDigit(raw[cursor + 1])) {
        number
          ..write('.')
          ..write(raw[cursor + 1]);
        cursor += 2;
      } else {
        break;
      }
    }
    return _Number(number.toString(), cursor);
  }
}

/// A number found in a transcript, with the index just past its last character.
final class _Number {
  const _Number(this.text, this.lastIndex);

  final String text;
  final int lastIndex;
}
