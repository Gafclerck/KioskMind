/// Tunables of the voice pipeline, in one place.
///
/// No threshold, duration or word list is written inline anywhere else in the
/// module: a shop can change them without touching the logic, and a test can
/// state the value it depends on instead of hardcoding it.
///
/// The values below are the defaults used by the rule parser and the decision
/// policy. Nothing here is a displayable string.
final class VoiceConfig {
  const VoiceConfig({
    this.maxQuantity = kDefaultMaxQuantity,
    this.relativeQuantityTolerance = kDefaultRelativeTolerance,
    this.priceToleranceRatio = kDefaultPriceTolerance,
    this.fillers = kVoiceFillers,
    this.fuzzyThreshold = kDefaultFuzzyThreshold,
    this.ambiguityMargin = kDefaultAmbiguityMargin,
    this.underSpecifiedNames = kUnderSpecifiedNames,
  });

  /// Quantity above which a line is doubted rather than executed (contract A11).
  final double maxQuantity;

  /// Ratio between the spoken quantity and the usual one above which the line is
  /// doubted. Guards "trois cents biere" spoken for a glass.
  final double relativeQuantityTolerance;

  /// Ratio between the catalog price and the spoken one above which the price is
  /// doubted (contract A7).
  final double priceToleranceRatio;

  /// Filler words removed before parsing.
  final Set<String> fillers;

  /// Minimum similarity for a spoken word to be accepted as a misspelling of a
  /// catalog name. Below this, the word is unknown and the product is asked for.
  final double fuzzyThreshold;

  /// Two candidates closer than this are reported as ambiguous instead of
  /// silently picking the first.
  final double ambiguityMargin;

  /// Spoken names the shop treats as needing a qualifier, mapped to the catalog
  /// names they may stand for.
  ///
  /// The catalog cannot express this: "huile" is an alias of the vegetable oil
  /// and nothing else, yet saying "huile" in this shop does not say which oil,
  /// because two products answer to that word. It is a business fact, so it is
  /// data a shop can extend, not a rule buried in the parser.
  final Map<String, List<String>> underSpecifiedNames;

  VoiceConfig copyWith({
    double? maxQuantity,
    double? relativeQuantityTolerance,
    double? priceToleranceRatio,
    Set<String>? fillers,
    double? fuzzyThreshold,
    double? ambiguityMargin,
    Map<String, List<String>>? underSpecifiedNames,
  }) {
    return VoiceConfig(
      maxQuantity: maxQuantity ?? this.maxQuantity,
      relativeQuantityTolerance:
          relativeQuantityTolerance ?? this.relativeQuantityTolerance,
      priceToleranceRatio: priceToleranceRatio ?? this.priceToleranceRatio,
      fillers: fillers ?? this.fillers,
      fuzzyThreshold: fuzzyThreshold ?? this.fuzzyThreshold,
      ambiguityMargin: ambiguityMargin ?? this.ambiguityMargin,
      underSpecifiedNames: underSpecifiedNames ?? this.underSpecifiedNames,
    );
  }
}

const double kDefaultMaxQuantity = 1000;

const double kDefaultRelativeTolerance = 3;

const double kDefaultPriceTolerance = 0.2;

const double kDefaultFuzzyThreshold = 0.78;

const double kDefaultAmbiguityMargin = 0.08;

/// Names that do not identify a product on their own.
///
/// A shop selling both a vegetable oil and a palm oil hears "huile" without
/// knowing which one is meant, and picking one would record a movement for the
/// wrong product. Declaring it here keeps the choice with the shop instead of
/// the parser.
const Map<String, List<String>> kUnderSpecifiedNames = <String, List<String>>{
  'huile': <String>['huile', 'huiles', 'huile palme', 'huile de palme'],
  'huiles': <String>['huiles', 'huile palme', 'huile de palme'],
};

/// Words a merchant says without meaning anything for the command.
///
/// Each one is a single token, so removal is order-independent and cannot join
/// two words that were actually separate. Anything carrying meaning is
/// deliberately absent: not the articles ("un" announces a quantity), not "de"
/// (a partitive marks the quantity as unstated), not "en" (it belongs to the
/// alias "sucre en poudre"), and not "non" (it cancels a previous mention).
const Set<String> kVoiceFillers = <String>{
  'euh',
  'hein',
  'voila',
  'bonjour',
  'bonsoir',
  'alors',
  'aussi',
  'peu',
};
