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
    this.unusualQuantityThreshold = kDefaultUnusualQuantity,
    this.shopQuantityCeiling = kDefaultShopQuantityCeiling,
    this.priceToleranceRatio = kDefaultPriceTolerance,
    this.fillers = kVoiceFillers,
    this.fuzzyThreshold = kDefaultFuzzyThreshold,
    this.ambiguityMargin = kDefaultAmbiguityMargin,
    this.underSpecifiedNames = kUnderSpecifiedNames,
    this.undoWindow = kDefaultUndoWindow,
    this.questionTimeout = kDefaultQuestionTimeout,
    this.confirmationTimeout = kDefaultConfirmationTimeout,
    this.maxClarificationTurns = kDefaultMaxClarificationTurns,
    this.sessionTimeout = kDefaultSessionTimeout,
  });

  /// Quantity of one product, in one breath, above which the line is confirmed
  /// rather than executed.
  ///
  /// Calibrated on the frozen text set, as `PIPELINE.md` prescribes for this
  /// kind of threshold, and reported with the curve in the step report. It is an
  /// absolute number rather than a ratio to the product's daily average on
  /// purpose: the voice module does not own the product schema, and a rule that
  /// needs a field the module cannot guarantee is a rule that silently stops
  /// working.
  final double unusualQuantityThreshold;

  /// Quantity of one product, in one breath, above which the number cannot be a
  /// quantity at all.
  ///
  /// It is a ceiling and not a doubt: above it the words cannot describe anything
  /// a shop sells, so the only honest issue is to refuse rather than to ask. The
  /// boundary itself is a frozen case (t112 expects a confirmation, not a
  /// refusal), which is why the comparison is strict.
  final double shopQuantityCeiling;

  /// Ratio between the catalog price and the spoken one above which the price is
  /// confirmed rather than applied (contract A7). Inclusive: a gap of exactly
  /// this ratio is still the catalog price.
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

  /// How long the "undo" banner stays available after a write.
  final Duration undoWindow;

  /// How long the session waits for an answer before offering manual entry.
  ///
  /// Every wait has one, so no state can trap the merchant in a question they
  /// cannot leave: silence ends the question rather than the morning.
  final Duration questionTimeout;

  /// How long the session waits for confirmation before offering manual entry.
  ///
  /// Confirmations include a recap read aloud by text-to-speech (TTS), which
  /// takes 3-6 seconds. A 30s timeout gives the merchant plenty of time to
  /// listen and answer naturally without dropping to manual entry.
  final Duration confirmationTimeout;

  /// How many questions one command may draw before manual entry is offered.
  final int maxClarificationTurns;

  /// How long a session stays alive without an utterance.
  final Duration sessionTimeout;

  VoiceConfig copyWith({
    double? unusualQuantityThreshold,
    double? shopQuantityCeiling,
    double? priceToleranceRatio,
    Set<String>? fillers,
    double? fuzzyThreshold,
    double? ambiguityMargin,
    Map<String, List<String>>? underSpecifiedNames,
    Duration? undoWindow,
    Duration? questionTimeout,
    Duration? confirmationTimeout,
    int? maxClarificationTurns,
    Duration? sessionTimeout,
  }) {
    return VoiceConfig(
      unusualQuantityThreshold:
          unusualQuantityThreshold ?? this.unusualQuantityThreshold,
      shopQuantityCeiling: shopQuantityCeiling ?? this.shopQuantityCeiling,
      priceToleranceRatio: priceToleranceRatio ?? this.priceToleranceRatio,
      fillers: fillers ?? this.fillers,
      fuzzyThreshold: fuzzyThreshold ?? this.fuzzyThreshold,
      ambiguityMargin: ambiguityMargin ?? this.ambiguityMargin,
      underSpecifiedNames: underSpecifiedNames ?? this.underSpecifiedNames,
      undoWindow: undoWindow ?? this.undoWindow,
      questionTimeout: questionTimeout ?? this.questionTimeout,
      confirmationTimeout: confirmationTimeout ?? this.confirmationTimeout,
      maxClarificationTurns:
          maxClarificationTurns ?? this.maxClarificationTurns,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
    );
  }
}

/// Durations and turn counts of the dialogue, from the table in PIPELINE.md
/// section 7. The two timeouts are equal on purpose: a question that goes
/// unanswered and a session nobody returns to end the same way, by offering the
/// screens, so one value says both.
const Duration kDefaultUndoWindow = Duration(seconds: 10);

const Duration kDefaultQuestionTimeout = Duration(seconds: 10);

const Duration kDefaultConfirmationTimeout = Duration(seconds: 30);

const Duration kDefaultSessionTimeout = Duration(seconds: 30);

const int kDefaultMaxClarificationTurns = 2;

/// Above this many units of one product, the merchant is asked to confirm.
///
/// Calibrated on the frozen text set: 20 separates the cases that execute from
/// the ones that confirm better than any ratio to a per-product average, because
/// the set contradicts itself on ratios (fifteen units confirm for dry pasta,
/// execute for sugar).
const double kDefaultUnusualQuantity = 20;

/// Above this many units of one product, the words cannot be a quantity.
///
/// A thousand units of anything is a recognition error, not a sale, and the
/// module has no way to tell which number was meant, so refusing is the only
/// answer it can defend. Strictly greater: one thousand is still a quantity.
const double kDefaultShopQuantityCeiling = 1000;

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
