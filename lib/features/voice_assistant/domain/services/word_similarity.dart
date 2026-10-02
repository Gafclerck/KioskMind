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

  /// Edit distance between two words, computed on one row of the usual table.
  static int _distance(String left, String right) {
    List<int> previous = List<int>.generate(
      right.length + 1,
      (int index) => index,
      growable: false,
    );
    List<int> current = List<int>.filled(right.length + 1, 0, growable: false);
    for (int i = 1; i <= left.length; i++) {
      current[0] = i;
      for (int j = 1; j <= right.length; j++) {
        final int substitution =
            previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1);
        final int deletion = previous[j] + 1;
        final int insertion = current[j - 1] + 1;
        current[j] = _min3(substitution, deletion, insertion);
      }
      final List<int> swap = previous;
      previous = current;
      current = swap;
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
