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

  /// Damerau-Levenshtein (OSA) distance between two words.
  ///
  /// Supports insertions, deletions, substitutions, and transpositions of
  /// adjacent characters.
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

    List<int> twoPrevious = List<int>.filled(
      right.length + 1,
      0,
      growable: false,
    );
    List<int> previous = List<int>.generate(
      right.length + 1,
      (int index) => index,
      growable: false,
    );
    List<int> current = List<int>.filled(right.length + 1, 0, growable: false);

    for (int i = 1; i <= left.length; i++) {
      current[0] = i;
      for (int j = 1; j <= right.length; j++) {
        final int cost = left[i - 1] == right[j - 1] ? 0 : 1;
        final int substitution = previous[j - 1] + cost;
        final int deletion = previous[j] + 1;
        final int insertion = current[j - 1] + 1;
        int distance = _min3(substitution, deletion, insertion);

        if (i > 1 &&
            j > 1 &&
            left[i - 1] == right[j - 2] &&
            left[i - 2] == right[j - 1]) {
          final int transposition = twoPrevious[j - 2] + 1;
          if (transposition < distance) {
            distance = transposition;
          }
        }
        current[j] = distance;
      }
      final List<int> swapTwo = twoPrevious;
      twoPrevious = previous;
      previous = current;
      current = swapTwo;
    }
    return previous[right.length];
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
