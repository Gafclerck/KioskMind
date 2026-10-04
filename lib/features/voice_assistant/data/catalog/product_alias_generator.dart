/// Generates spoken aliases and phonetic search forms from a product name.
///
/// Enables natural spoken matching without requiring the merchant to manually
/// configure synonyms for every product in stock.
abstract final class ProductAliasGenerator {
  static final RegExp _unitsRegex = RegExp(
    r'\b\d+([.,]\d+)?\s*(kg|kilos?|kilogrammes?|g|grammes?|l|litres?|ml|cl|cm|m)\b',
    caseSensitive: false,
  );

  static final RegExp _standaloneDigits = RegExp(r'\b\d+([.,]\d+)?\b');

  static final RegExp _packagingPrefixes = RegExp(
    r'^(sac|sacs|sachet|sachets|carton|cartons|boite|boites|boîte|boîtes|bidon|bidons|bouteille|bouteilles|paquet|paquets|pack|packs|plaquette|plaquettes|filet|filets)\s+(de|du|d\x27|des|d)\s+',
    caseSensitive: false,
  );

  static const Set<String> _stopWords = <String>{
    'de',
    'du',
    'des',
    'le',
    'la',
    'les',
    'un',
    'une',
    'en',
    'pour',
    'avec',
    'sur',
    'sous',
    'dans',
    'par',
    'aux',
    'au',
    'd',
    'l',
    'sac',
    'sacs',
    'sachet',
    'sachets',
    'carton',
    'cartons',
    'boite',
    'boites',
    'boîte',
    'boîtes',
    'bidon',
    'bidons',
    'bouteille',
    'bouteilles',
    'paquet',
    'paquets',
    'pack',
    'packs',
    'kg',
    'kilo',
    'kilos',
    'litre',
    'litres',
    'g',
    'gramme',
    'grammes',
    'ml',
    'cl',
  };

  /// Generates a set of spoken alias candidates derived from [name].
  static List<String> generate(String name) {
    if (name.trim().isEmpty) {
      return const <String>[];
    }

    final Set<String> aliases = <String>{};
    final String trimmed = name.trim();
    final String lower = trimmed.toLowerCase();
    aliases.add(lower);

    // 1. Unaccented version (e.g. "riz parfumé" -> "riz parfume")
    final String unaccented = _stripAccents(lower);
    if (unaccented != lower) {
      aliases.add(unaccented);
    }

    // 2. Strip weights, volumes, packaging dimensions (e.g. "50kg", "1.5L", "500g", "200 ml")
    final String withoutUnits = _stripUnitsAndWeights(lower);
    if (withoutUnits.isNotEmpty && withoutUnits != lower) {
      aliases.add(withoutUnits);
      final String unaccentedWithoutUnits = _stripAccents(withoutUnits);
      if (unaccentedWithoutUnits != withoutUnits) {
        aliases.add(unaccentedWithoutUnits);
      }
    }

    // 3. Strip packaging prefix words (e.g. "sac de riz" -> "riz", "carton de sucre" -> "sucre")
    final String candidateForPrefix = withoutUnits.isNotEmpty
        ? withoutUnits
        : lower;
    final String baseProduct = candidateForPrefix
        .replaceFirst(_packagingPrefixes, '')
        .trim();
    if (baseProduct.isNotEmpty &&
        baseProduct != lower &&
        baseProduct != withoutUnits) {
      aliases.add(baseProduct);
      final String unaccentedBase = _stripAccents(baseProduct);
      if (unaccentedBase != baseProduct) {
        aliases.add(unaccentedBase);
      }
    }

    // 4. Extract individual distinctive words (length >= 3, non-stopwords)
    final List<String> words = lower.split(RegExp(r'[\s\-_.,/]+'));
    for (final String word in words) {
      final String cleanWord = _stripAccents(word).trim();
      if (cleanWord.length >= 3 && !_stopWords.contains(cleanWord)) {
        aliases.add(cleanWord);
      }
    }

    // Sort by descending token length, then alphabetical for deterministic ordering
    final List<String> result = aliases
        .where((String a) => a.trim().isNotEmpty)
        .toList();
    result.sort((String a, String b) {
      final int tokensA = a.split(' ').length;
      final int tokensB = b.split(' ').length;
      if (tokensA != tokensB) {
        return tokensB.compareTo(tokensA);
      }
      final int lenDiff = b.length.compareTo(a.length);
      return lenDiff != 0 ? lenDiff : a.compareTo(b);
    });

    return result;
  }

  static String _stripAccents(String input) {
    return input
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  static String _stripUnitsAndWeights(String input) {
    return input
        .replaceAll(_unitsRegex, '')
        .replaceAll(_standaloneDigits, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
