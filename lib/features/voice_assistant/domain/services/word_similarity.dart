/// How close two spoken words are, on a scale where 1 is identical.
///
/// The rule parser needs to accept a misspelling a recognizer or a merchant
/// produces ("magis" for "Maggi") without ever inventing a product. Comparing
/// words is pure arithmetic, so it lives in the domain and is exercised by
/// plain table-driven tests.
final class WordSimilarity {
  const WordSimilarity._();

  /// Levenshtein similarity: one minus the edit distance over the longer word.
  ///
  /// Normalizing by the longer word keeps the score symmetric and prevents a
  /// short word from matching a long one on a single edit.
  static double of(String spoken, String expected) {
    if (spoken == expected) {
      return 1;
    }
    final int longest = spoken.length > expected.length
        ? spoken.length
        : expected.length;
    if (longest == 0) {
      return 1;
    }
    return 1 - _distance(spoken, expected) / longest;
  }

  /// The forms of a spoken noun to try, most likely first.
  ///
  /// A merchant says "deux rizes" where the catalog says "riz". Singular and
  /// plural both reach the resolver, and so do the several spellings French
  /// allows for the same plural.
  static List<String> nounForms(String spoken) {
    final Set<String> forms = <String>{spoken};
    if (spoken.endsWith('eaux')) {
      forms.add(spoken.substring(0, spoken.length - 1));
    }
    if (spoken.endsWith('aux')) {
      forms.add(spoken.substring(0, spoken.length - 3));
    }
    if (spoken.endsWith('es')) {
      forms.add(spoken.substring(0, spoken.length - 2));
      forms.add('${spoken.substring(0, spoken.length - 2)}s');
    }
    if (spoken.endsWith('s')) {
      forms.add(spoken.substring(0, spoken.length - 1));
    }
    return forms.toList(growable: false);
  }

  static const int _maxStaticLength = 64;
  static final List<int> _bufferA = List<int>.filled(_maxStaticLength + 1, 0);
  static final List<int> _bufferB = List<int>.filled(_maxStaticLength + 1, 0);
  static final List<int> _bufferC = List<int>.filled(_maxStaticLength + 1, 0);

  /// Damerau-Levenshtein (OSA) distance between two words.
  ///
  /// Supports insertions, deletions, substitutions, and transpositions of
  /// adjacent characters.
  /// Uses isolate-local reusable row buffers and `codeUnitAt` to avoid heap
  /// allocations during fuzzy comparison loops.
  static int _distance(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    // Keep right as the shorter word to minimize row buffer length.
    if (left.length < right.length) {
      return _distance(right, left);
    }

    final int n = right.length;
    final List<int> twoPrevious;
    final List<int> previous;
    final List<int> current;

    if (n <= _maxStaticLength) {
      twoPrevious = _bufferA;
      previous = _bufferB;
      current = _bufferC;
      for (int j = 0; j <= n; j++) {
        previous[j] = j;
        twoPrevious[j] = 0;
      }
    } else {
      twoPrevious = List<int>.filled(n + 1, 0, growable: false);
      previous = List<int>.generate(
        n + 1,
        (int index) => index,
        growable: false,
      );
      current = List<int>.filled(n + 1, 0, growable: false);
    }

    List<int> r0 = twoPrevious;
    List<int> r1 = previous;
    List<int> r2 = current;

    for (int i = 1; i <= left.length; i++) {
      r2[0] = i;
      final int leftChar = left.codeUnitAt(i - 1);
      final int? leftPrevChar = i > 1 ? left.codeUnitAt(i - 2) : null;

      for (int j = 1; j <= n; j++) {
        final int rightChar = right.codeUnitAt(j - 1);
        final int cost = leftChar == rightChar ? 0 : 1;
        final int substitution = r1[j - 1] + cost;
        final int deletion = r1[j] + 1;
        final int insertion = r2[j - 1] + 1;
        int distance = _min3(substitution, deletion, insertion);

        if (leftPrevChar != null && j > 1) {
          final int rightPrevChar = right.codeUnitAt(j - 2);
          if (leftChar == rightPrevChar && leftPrevChar == rightChar) {
            final int transposition = r0[j - 2] + 1;
            if (transposition < distance) {
              distance = transposition;
            }
          }
        }
        r2[j] = distance;
      }
      final List<int> swap = r0;
      r0 = r1;
      r1 = r2;
      r2 = swap;
    }
    return r1[n];
  }

  static int _min3(int a, int b, int c) {
    int smallest = a;
    if (b < smallest) {
      smallest = b;
    }
    if (c < smallest) {
      smallest = c;
    }
    return smallest;
  }
}
