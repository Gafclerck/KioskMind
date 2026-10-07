import '../../domain/entities/doubt.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/entities/slot.dart';
import '../../domain/entities/voice_lexicon.dart';
import '../../domain/services/french_number_parser.dart';
import '../catalog/product_resolver.dart';
import 'line_extractor.dart';

/// The lines of a command, with everything that keeps them from being executed.
final class ItemListReading {
  const ItemListReading({
    required this.items,
    required this.products,
    required this.doubts,
  });

  /// One entry per product the merchant named and did not take back, with a
  /// quantity to record.
  final List<ItemMention> items;

  /// Every product the merchant named, whether or not a count was spoken. A
  /// question needs the product only, so it reads this list.
  final List<ProductSnapshot> products;

  final List<Doubt> doubts;
}

/// Finds the products of a command and reads the quantity and amount of each.
///
/// Resolution stays the resolver's job: this only decides which spans of the
/// utterance are product names, drops the ones the merchant took back, and asks
/// the line extractor what belongs to each survivor.
final class ItemListExtractor {
  const ItemListExtractor({required this.resolver, required this.lines});

  final ProductResolver resolver;
  final LineExtractor lines;

  /// Reads the products named from [from] onwards.
  ///
  /// [requiresQuantity] is false for a question: "combien de riz" has no count
  /// and is still complete, while "vendu du riz" without a count is not.
  ///
  /// Every doubt about a line carries what the merchant did say about it, so that
  /// Reads the products named in [tokens], ignoring the trigger span [triggerStart, triggerEnd].
  ///
  /// [requiresQuantity] is false for a question: "combien de riz" has no count
  /// and is still complete, while "vendu du riz" without a count is not.
  ///
  /// Every doubt about a line carries what the merchant did say about it, so that
  /// the answer to the question completes the line. The reading never invents a
  /// count: a line the merchant left half said stays half said.
  ItemListReading read(
    List<String> tokens, {
    required int from,
    required bool requiresQuantity,
    int triggerStart = 0,
    int? triggerEnd,
  }) {
    final int effectiveTriggerEnd = triggerEnd ?? from;
    final List<_Mention> mentions = _keptMentions(
      tokens,
      triggerStart: triggerStart,
      triggerEnd: effectiveTriggerEnd,
    );
    final List<Doubt> doubts = <Doubt>[];
    final List<ItemMention> items = <ItemMention>[];
    final List<ProductSnapshot> products = <ProductSnapshot>[];

    for (int i = 0; i < mentions.length; i++) {
      final _Mention mention = mentions[i];
      final int? nextProductStart = i + 1 < mentions.length
          ? mentions[i + 1].start
          : null;
      final LineReading reading = lines.read(
        tokens,
        mention.start,
        productLength: mention.length,
        nextProductStart: nextProductStart,
      );
      final double? quantity = _quantityOf(reading);
      final Doubt? doubt = _doubtOf(mention.resolution, quantity);
      if (doubt != null) {
        doubts.add(doubt);
        continue;
      }
      final ProductSnapshot product = mention.resolution.product!;
      products.add(product);
      doubts.addAll(_lineDoubts(reading, requiresQuantity, quantity, product));
      if (quantity != null) {
        items.add(
          ItemMention(
            product: product,
            qty: quantity,
            spokenAmount: reading.amount,
          ),
        );
      }
    }
    if (mentions.isEmpty) {
      doubts.add(
        _noProductDoubt(
          tokens,
          triggerStart: triggerStart,
          triggerEnd: effectiveTriggerEnd,
          requiresQuantity: requiresQuantity,
        ),
      );
    }
    return ItemListReading(items: items, products: products, doubts: doubts);
  }

  /// The doubt an utterance that named no product raises.
  ///
  /// "vendu un truc" named something the catalog does not hold, "vendu du sucre"
  /// named nothing at all: the difference is what the merchant is told. The count
  /// is read as if the missing name stood at the end of the utterance, which is
  /// where the reader looks back from, so "vendu deux sachets" keeps its two.
  Doubt _noProductDoubt(
    List<String> tokens, {
    required int triggerStart,
    required int triggerEnd,
    required bool requiresQuantity,
  }) {
    return Doubt(
      kind:
          _namesSomething(
            tokens,
            triggerStart: triggerStart,
            triggerEnd: triggerEnd,
            mentions: const <_Mention>[],
          )
          ? DoubtKind.unknownProduct
          : DoubtKind.missingProduct,
      partial: (
        product: null,
        qty: requiresQuantity
            ? lines.read(tokens, tokens.length).quantity
            : null,
      ),
    );
  }

  /// The count of a line, when one can be said without inventing it.
  ///
  /// A line that announces its amount and no count is one unit at that amount:
  /// "reçu du riz à 560" names the product and what it cost, and one unit is the
  /// only count that sentence can mean. A bare partitive carries no such hint, so
  /// "vendu du sucre" stays a question rather than becoming a sale of one.
  static double? _quantityOf(LineReading reading) {
    if (reading.quantity != null) {
      return reading.quantity;
    }
    return reading.amount == null ? null : 1;
  }

  /// Every product name outside the trigger span, minus the ones a correction undid.
  List<_Mention> _keptMentions(
    List<String> tokens, {
    required int triggerStart,
    required int triggerEnd,
  }) {
    final List<_Mention> found = <_Mention>[];
    int index = 0;
    while (index < tokens.length) {
      if (index >= triggerStart && index < triggerEnd) {
        index = triggerEnd;
        continue;
      }
      final ProductSpan? span = resolver.matchAt(tokens, index);
      if (span == null) {
        index++;
        continue;
      }
      found.add(
        _Mention(
          start: span.start,
          length: span.length,
          resolution: span.resolution,
        ),
      );
      index += span.length;
    }
    return _withoutCorrected(found, tokens);
  }

  /// Drops a name the merchant took back: "un sucre, non, un riz" is one line.
  ///
  /// The correction reaches back to the previous name only. Words after the last
  /// name are ignored, since a correction with nothing to cancel is not a
  /// correction.
  List<_Mention> _withoutCorrected(List<_Mention> found, List<String> tokens) {
    final List<_Mention> kept = <_Mention>[];
    for (int index = 0; index < found.length; index++) {
      final _Mention mention = found[index];
      final int limit = index + 1 < found.length
          ? found[index + 1].start
          : tokens.length;
      if (_isCorrected(tokens, mention.end, limit)) {
        continue;
      }
      kept.add(mention);
    }
    return kept;
  }

  static bool _isCorrected(List<String> tokens, int from, int to) {
    for (int index = from; index < to && index < tokens.length; index++) {
      if (kCorrectionWords.contains(tokens[index])) {
        return true;
      }
    }
    return false;
  }

  /// The doubt a product name raises, or null when it names a usable product.
  ///
  /// A name that cannot be used still leaves the line it was part of standing: the
  /// count spoken with it is kept so the answer keeps the count too.
  Doubt? _doubtOf(ProductResolution resolution, double? quantity) {
    switch (resolution.status) {
      case ResolutionStatus.resolved:
        return null;
      case ResolutionStatus.ambiguous:
        return Doubt(
          kind: DoubtKind.ambiguousProduct,
          candidates: resolution.products,
          partial: (product: null, qty: quantity),
        );
      case ResolutionStatus.archived:
        return Doubt(
          kind: DoubtKind.archivedProduct,
          partial: (product: null, qty: quantity),
        );
      case ResolutionStatus.unknown:
        return Doubt(
          kind: DoubtKind.unknownProduct,
          partial: (product: null, qty: quantity),
        );
    }
  }

  /// What one line is missing, if anything.
  ///
  /// Asked of the count the line really carries, not of what was spoken, so a
  /// unit implied by an announced amount is not reported as missing. The product is
  /// carried along: it is the half of the line that was said, and asking the count
  /// must not throw it away.
  List<Doubt> _lineDoubts(
    LineReading reading,
    bool requiresQuantity,
    double? quantity,
    ProductSnapshot product,
  ) {
    if (quantity == null) {
      return requiresQuantity
          ? <Doubt>[
              Doubt(
                kind: DoubtKind.missingQuantity,
                partial: (product: product, qty: null),
              ),
            ]
          : const <Doubt>[];
    }
    if (quantity <= 0) {
      return const <Doubt>[Doubt(kind: DoubtKind.invalidQuantity)];
    }
    return const <Doubt>[];
  }

  /// Whether a plain word stands where a product was expected.
  ///
  /// Bounded to the words that precede the last name actually found, skipping
  /// the trigger span itself, so neither the trigger nor the chatter after a
  /// command can turn a complete line into an unknown product.
  bool _namesSomething(
    List<String> tokens, {
    required int triggerStart,
    required int triggerEnd,
    required List<_Mention> mentions,
  }) {
    final int limit = mentions.isEmpty ? tokens.length : mentions.last.end;
    for (int index = 0; index < limit; index++) {
      if (index >= triggerStart && index < triggerEnd) {
        continue;
      }
      final String token = tokens[index];
      if (_isPlaceholder(token)) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// A word that cannot be the product name: a number, an article, a unit, or a
  /// word the lexicon already accounts for.
  static bool _isPlaceholder(String token) {
    if (kQuantityBridges.contains(token) ||
        kUnitWords.contains(token) ||
        kCurrencyWords.contains(token) ||
        kCorrectionWords.contains(token) ||
        FrenchNumberParser.isNumberToken(token)) {
      return true;
    }
    return false;
  }
}

/// The span of a product, and where it stands in the utterance.
final class _Mention {
  const _Mention({
    required this.start,
    required this.length,
    required this.resolution,
  });

  final int start;

  /// Number of tokens the product name spans.
  final int length;

  final ProductResolution resolution;

  /// Index just past the name.
  int get end => start + length;
}
