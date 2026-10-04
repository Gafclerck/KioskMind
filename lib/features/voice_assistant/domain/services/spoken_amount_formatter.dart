/// Reads a money amount in French words, for the voice recap.
///
/// A synthesiser handed `1250.0` reads a decimal, or reads nothing at all. Neither
/// is what a merchant should hear for a price, so every amount that reaches the
/// speech port goes through this formatter first.
///
/// The rules are the ordinary French ones: `quatre-vingts` takes an s only when
/// nothing follows it, `soixante et onze` but `quatre-vingt-onze`, `mille` never
/// takes an s and never a "un". The XOF has no decimals (A1 of
/// `USE_CASE_CONTRACTS.md`), so an amount is rounded to the whole franc and the
/// currency word stays with the caller: it is text, and text belongs to the
/// localisation layer, not here.
///
/// French is a property of this formatter, not of the module. A second language
/// gets a second formatter behind the same call, and no caller changes.
final class SpokenAmountFormatter {
  const SpokenAmountFormatter();

  /// Largest amount this formatter reads, so the tables below stay finite.
  static const int _largestAmount = 999999999;

  static const List<String> _units = <String>[
    'zéro', 'un', 'deux', 'trois', 'quatre', //
    'cinq', 'six', 'sept', 'huit', 'neuf', //
    'dix', 'onze', 'douze', 'treize', 'quatorze',
    'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf',
  ];

  static const List<String> _tens = <String>[
    '',
    '',
    'vingt',
    'trente',
    'quarante',
    'cinquante',
    'soixante',
  ];

  /// The [amount] in French words, rounded to the whole franc.
  ///
  /// Throws [ArgumentError] on anything that is not a non-negative finite amount:
  /// reading "moins cent" aloud would be worse than refusing to read.
  String call(double amount) {
    if (amount.isNaN || amount.isInfinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'montant non lisible');
    }
    final int francs = amount.round();
    if (francs > _largestAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'montant au dela de ce qui se dit',
      );
    }
    return _under1000000000(francs, true);
  }

  /// 0 to 99, where French needs its own rule at every decade.
  ///
  /// [isFinal] says this group is the last thing said, which is what decides the
  /// s of "quatre-vingts": "quatre-vingts" alone, "quatre-vingt mille" not.
  String _under100(int n, bool isFinal) {
    if (n < 20) {
      return _units[n];
    }
    if (n < 70) {
      final int unit = n % 10;
      final String head = _tens[n ~/ 10];
      if (unit == 0) {
        return head;
      }
      return unit == 1 ? '$head et un' : '$head-${_units[unit]}';
    }
    if (n == 71) {
      return 'soixante et onze';
    }
    if (n < 80) {
      return 'soixante-${_under100(n - 60, true)}';
    }
    final int rest = n - 80;
    return rest == 0
        ? (isFinal ? 'quatre-vingts' : 'quatre-vingt')
        : 'quatre-vingt-${_under100(rest, true)}';
  }

  /// 0 to 999. "cents" takes an s only when it ends the number.
  String _under1000(int n, bool isFinal) {
    if (n < 100) {
      return _under100(n, isFinal);
    }
    final int hundreds = n ~/ 100;
    final int rest = n % 100;
    final String head = hundreds == 1
        ? 'cent'
        : '${_under100(hundreds, false)} cent';
    if (rest != 0) {
      return '$head ${_under100(rest, isFinal)}';
    }
    return isFinal && hundreds > 1 ? '${head}s' : head;
  }

  /// 0 to 999999. "mille" is invariable and is never preceded by "un".
  String _under1000000(int n, bool isFinal) {
    if (n < 1000) {
      return _under1000(n, isFinal);
    }
    final int rest = n % 1000;
    final String head = n ~/ 1000 == 1
        ? 'mille'
        : '${_under1000(n ~/ 1000, false)} mille';
    return rest == 0 ? head : '$head ${_under1000000(rest, isFinal)}';
  }

  /// 0 to 999999999, the range [_largestAmount] allows.
  String _under1000000000(int n, bool isFinal) {
    if (n < 1000000) {
      return _under1000000(n, isFinal);
    }
    final int rest = n % 1000000;
    final String head = n ~/ 1000000 == 1
        ? 'un million'
        : '${_under1000(n ~/ 1000000, false)} millions';
    return rest == 0 ? head : '$head ${_under1000000(rest, isFinal)}';
  }
}
