import '../../domain/entities/voice_config.dart';
import '../../domain/entities/voice_lexicon.dart';
import '../../domain/services/french_number_parser.dart';
import '../../domain/services/word_similarity.dart';

/// Shortest word that may be read as a misheard unit.
///
/// Below four letters one edit is a third of the word, and a short word is far
/// more likely to be a name than a mangled unit.
const int kMinFuzzyUnitLength = 4;

/// What the words around one product name say about its line.
final class LineReading {
  const LineReading({this.quantity, this.amount});

  /// Quantity in the product's own unit, or null when none was spoken.
  final double? quantity;

  /// Amount announced for the line, or null.
  final double? amount;
}

/// Reads the quantity and the amount that go with one spoken product name.
///
/// Pure and bounded: it looks a few tokens back for the number that counts the
/// product and a few forward for the price, then stops. The bound matters, since
/// an unbounded search would let a number spoken much earlier belong to whichever
/// product happens to follow it.
final class LineExtractor {
  LineExtractor({required this.numbers, required VoiceConfig config})
    : _fuzzyThreshold = config.fuzzyThreshold;

  final FrenchNumberParser numbers;

  /// Tolerance for reading a misheard unit as the unit it was meant to be.
  final double _fuzzyThreshold;

  /// Reads the line of the product starting at [start] and spanning [productLength] tokens.
  ///
  /// [start] is the first token of the name, so the words that may precede it are
  /// the ones just before that, and the words that may follow it start at
  /// `start + productLength`.
  LineReading read(List<String> tokens, int start, {int productLength = 1}) {
    return LineReading(
      quantity: _quantity(tokens, start, productLength),
      amount: _amount(tokens, start),
    );
  }

  /// The number that counts the product, given a unit or a partitive in between.
  ///
  /// "cinq sachets de sucre" is five, not one and not "sachets". The search
  /// takes the longest number that ends exactly where the bridges stop, so
  /// "trois cents pates" is three hundred and not the hundred of "cents".
  /// If no count precedes the product, it checks for a repetition or a
  /// post-product count such as "savon deux" or "riz 3 sacs".
  double? _quantity(List<String> tokens, int start, int productLength) {
    final int anchor = _bridgeEnd(tokens, start);
    final double? before = _numberEndingAt(tokens, anchor);
    if (before != null) {
      return before;
    }
    final double? repeated = _repeatedCount(tokens, start);
    if (repeated != null) {
      return repeated;
    }
    return _postProductQuantity(tokens, start + productLength);
  }

  /// Reads a quantity directly following the product name, as in "savon deux" or "riz trois sacs".
  double? _postProductQuantity(List<String> tokens, int afterIndex) {
    if (afterIndex >= tokens.length) {
      return null;
    }
    // Price introduced by 'a' is not a quantity.
    if (tokens[afterIndex] == 'a') {
      return null;
    }
    // Stop at sentence connectors, corrections or question markers.
    if (tokens[afterIndex] == 'et' ||
        tokens[afterIndex] == 'ou' ||
        tokens[afterIndex] == 'combien' ||
        kCorrectionWords.contains(tokens[afterIndex])) {
      return null;
    }

    int cursor = afterIndex;
    // Allow optional bridge ("de", "d'") before the count, e.g. "savon de deux".
    while (cursor < tokens.length &&
        kQuantityBridges.contains(tokens[cursor])) {
      cursor++;
    }

    if (cursor < tokens.length) {
      final ParsedNumber? number = numbers.readAt(tokens, cursor);
      if (number != null && number.value > 0) {
        return number.value;
      }
    }
    return null;
  }

  /// The first index before [start] that is neither a bridge nor a unit.
  int _bridgeEnd(List<String> tokens, int start) {
    final int floor = start - kQuantityReach < 0 ? 0 : start - kQuantityReach;
    int anchor = start;
    while (anchor > floor && _isBridge(tokens[anchor - 1])) {
      anchor--;
    }
    return anchor;
  }

  bool _isBridge(String token) {
    return kQuantityBridges.contains(token) || _isUnit(token);
  }

  /// Whether the token is a unit, or a unit a recognizer mangled.
  ///
  /// "2 saché" and "2 sachett" are the two sachets the merchant said, and the
  /// same tolerance the resolver already applies to product names applies here:
  /// a word within [VoiceConfig.fuzzyThreshold] of a unit is that unit. Numbers
  /// are excluded, so a quantity is never read as a unit, and short words are
  /// left out because one edit is too much of a word to be a coincidence.
  bool _isUnit(String token) {
    if (kUnitWords.contains(token)) {
      return true;
    }
    if (token.length < kMinFuzzyUnitLength ||
        FrenchNumberParser.isNumberToken(token)) {
      return false;
    }
    for (final String unit in kUnitWords) {
      if (WordSimilarity.of(token, unit) >= _fuzzyThreshold) {
        return true;
      }
    }
    return false;
  }

  /// The longest number ending exactly at [anchor], or null.
  ///
  /// Scanned from the furthest start, so the longest reading wins: "trois cents
  /// pates" is three hundred and not the hundred of "cents", and "quatre-vingt-dix
  /// cafe" is ninety and not the ten of "dix". Only a reading that ends exactly
  /// where the bridges stop is accepted, so a number spoken much earlier is never
  /// borrowed by whichever product happens to follow it.
  double? _numberEndingAt(List<String> tokens, int anchor) {
    final int floor = anchor - kQuantityReach < 0 ? 0 : anchor - kQuantityReach;
    for (int start = floor; start < anchor; start++) {
      final ParsedNumber? number = numbers.readAt(tokens, start);
      if (number != null && start + number.consumed == anchor) {
        return number.value;
      }
    }
    return null;
  }

  /// "vendu du sucre deux fois" is two sales of a product named without a count.
  ///
  /// Counted after the name rather than before it, which is the only place French
  /// puts a repetition.
  double? _repeatedCount(List<String> tokens, int start) {
    final int limit = tokens.length < start + kQuantityReach + 1
        ? tokens.length
        : start + kQuantityReach + 1;
    for (int index = start; index < limit; index++) {
      if (tokens[index] != 'fois') {
        continue;
      }
      if (index == 0) {
        return null;
      }
      final ParsedNumber? number = numbers.readAt(tokens, index - 1);
      if (number != null && index - 1 + number.consumed == index) {
        return number.value;
      }
      return null;
    }
    return null;
  }

  /// The amount announced just after the name, as in "a sept cents".
  ///
  /// Only a number introduced by "a" counts, and only within a few tokens, so
  /// "un riz a sept cents le kilo et un sucre" prices the rice and not the sugar.
  double? _amount(List<String> tokens, int start) {
    final int limit = tokens.length < start + kAmountReach + 1
        ? tokens.length
        : start + kAmountReach + 1;
    for (int index = start; index < limit; index++) {
      if (tokens[index] != 'a' || index + 1 >= tokens.length) {
        continue;
      }
      final ParsedNumber? number = numbers.readAt(tokens, index + 1);
      if (number == null) {
        continue;
      }
      return number.value;
    }
    return null;
  }
}
