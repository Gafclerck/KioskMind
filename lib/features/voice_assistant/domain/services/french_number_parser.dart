/// A number read from a transcript, with how much of the text it used.
final class ParsedNumber {
  const ParsedNumber({required this.value, required this.consumed});

  final double value;

  /// Number of tokens the value spans. A caller must resume after them so a
  /// number is never counted twice.
  final int consumed;

  @override
  String toString() => 'ParsedNumber($value, $consumed)';
}

/// Reads a French number written in words or digits.
///
/// Pure and total: the same tokens always give the same value, and text that
/// holds no number gives null instead of a guess. It is also what cross-checks
/// the number an LLM proposes, so a disagreement between the two can raise a
/// doubt rather than decide a sale.
final class FrenchNumberParser {
  const FrenchNumberParser();

  /// Numbers of one to sixteen, the only ones that combine additively.
  static const Map<String, int> _units = <String, int>{
    'zero': 0,
    'un': 1,
    'une': 1,
    'deux': 2,
    'trois': 3,
    'quatre': 4,
    'cinq': 5,
    'six': 6,
    'sept': 7,
    'huit': 8,
    'neuf': 9,
    'dix': 10,
    'onze': 11,
    'douze': 12,
    'treize': 13,
    'quatorze': 14,
    'quinze': 15,
    'seize': 16,
  };

  /// Tens that add to the units, like "soixante quinze" for seventy-five. Only
  /// "vingt" multiplies, because "quatre-vingt" is one value, not four and twenty.
  static const Map<String, int> _tens = <String, int>{
    'trente': 30,
    'quarante': 40,
    'cinquante': 50,
    'soixante': 60,
  };

  /// The two spellings of "vingt" that are not a multiplier.
  static const Set<String> _bareTwenty = <String>{'vingt', 'vingts'};

  /// "quatrevingt" written as one word: already multiplied, unlike the two words.
  static const Set<String> _joinedEighty = <String>{
    'quatrevingt',
    'quatrevingts',
  };

  static const Set<String> _hundred = <String>{'cent', 'cents'};

  /// A token that means nothing inside a number is skipped rather than ending
  /// it, because French inserts it: "soixante et une".
  static const Set<String> _joins = <String>{'et'};

  /// The value of the number starting at [index], or null when none does.
  ParsedNumber? readAt(List<String> tokens, int index) {
    if (index < 0 || index >= tokens.length) {
      return null;
    }
    final _Accumulator total = _Accumulator();
    int cursor = index;
    while (cursor < tokens.length) {
      final int before = cursor;
      if (!_consume(tokens, cursor, total)) {
        break;
      }
      cursor = before + total.consumedLast;
    }
    if (!total.sawAny) {
      return null;
    }
    return ParsedNumber(value: total.result, consumed: cursor - index);
  }

  /// Whether the token is a number on its own, in words or in digits.
  ///
  /// Lets a caller tell "a number was spoken here" from "a noun was spoken here"
  /// without parsing twice, which is what decides whether "vendu deux sachets" is
  /// a missing product or an unknown one.
  static bool isNumberToken(String token) {
    return _consume(<String>[token], 0, _Accumulator());
  }

  /// Adds the token at [index] to [total]. Returns false when it starts nothing.
  static bool _consume(List<String> tokens, int index, _Accumulator total) {
    final String token = tokens[index];
    total.consumedLast = 1;

    final double? digits = _asDouble(token);
    if (digits != null) {
      total.add(digits);
      return true;
    }
    if (_joins.contains(token)) {
      // Only meaningful between two numbers: "soixante et onze".
      return total.sawAny &&
          index + 1 < tokens.length &&
          _startsNumber(tokens[index + 1]);
    }
    if (_half.contains(token)) {
      total.setHalf();
      return true;
    }
    if (_units.containsKey(token)) {
      total.add(_units[token]!.toDouble());
      return true;
    }
    if (_tens.containsKey(token)) {
      total.add(_tens[token]!.toDouble());
      return true;
    }
    if (_bareTwenty.contains(token)) {
      total.multiplyBy(20);
      return true;
    }
    if (_joinedEighty.contains(token)) {
      total.add(80);
      return true;
    }
    if (_hundred.contains(token)) {
      total.multiplyBy(100);
      return true;
    }
    if (_thousand.contains(token)) {
      total.thousand();
      return true;
    }
    return false;
  }

  static const Set<String> _half = <String>{'demi'};

  static const Set<String> _thousand = <String>{'mille'};

  static bool _startsNumber(String token) {
    if (_asDouble(token) != null) {
      return true;
    }
    return _units.containsKey(token) ||
        _tens.containsKey(token) ||
        _bareTwenty.contains(token) ||
        _joinedEighty.contains(token) ||
        _hundred.contains(token) ||
        _thousand.contains(token);
  }

  static double? _asDouble(String token) {
    if (token.isEmpty) {
      return null;
    }
    for (final int rune in token.runes) {
      if (rune < 0x30 || rune > 0x39) {
        return token.contains('.') ? double.tryParse(token) : null;
      }
    }
    return double.tryParse(token);
  }
}

/// Running state of one number being read.
final class _Accumulator {
  /// The addend being built.
  double _pending = 0;

  /// Addends already closed by a "mille" or by a multiplier that ended its group.
  double _completed = 0;

  /// Set by "cent" and "vingt": the value they produced is complete, so the next
  /// spoken number starts a new addend. This is what makes "cent quatre-vingt-dix"
  /// one hundred plus ninety while "deux cent soixante-quinze" is two hundred and
  /// seventy-five.
  bool _restartNext = false;

  bool sawAny = false;

  /// Tokens the last accepted token spanned.
  int consumedLast = 1;

  void add(double value) {
    _closePending();
    _pending += value;
    sawAny = true;
  }

  /// "un demi": one unit halved, which is not the same as adding half.
  void setHalf() {
    _closePending();
    if (_pending == 1) {
      _pending = 0.5;
    } else {
      _pending += 0.5;
    }
    sawAny = true;
  }

  /// "vingt" and "cent" scale what came before, and stand alone as 20 and 100.
  void multiplyBy(int factor) {
    _closePending();
    if (_pending == 0) {
      _pending = factor.toDouble();
    } else {
      _pending *= factor;
    }
    _restartNext = true;
    sawAny = true;
  }

  /// "mille" applies to what came before it and closes that addend.
  void thousand() {
    _completed += (_pending == 0 ? 1 : _pending) * 1000;
    _pending = 0;
    _restartNext = false;
    sawAny = true;
  }

  double get result => _completed + _pending;

  void _closePending() {
    if (!_restartNext) {
      return;
    }
    _completed += _pending;
    _pending = 0;
    _restartNext = false;
  }
}
