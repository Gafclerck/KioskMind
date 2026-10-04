import '../entities/doubt.dart';
import '../entities/product_snapshot.dart';
import '../entities/voice_lexicon.dart';
import '../ports/spoken_product_resolver.dart';
import 'french_number_parser.dart';
import 'text_normalizer.dart';

/// Reads the answer the merchant just spoke, for the doubt it was asked about.
///
/// An answer is an utterance like any other, and it goes through the same reading
/// as one: the same normaliser, the same French numbers, the same product
/// resolution. What changes is that an utterance answering a question is never
/// handed to the intent detector. "sucre" alone is not a command, and a parser
/// that only accepts commands would report it as out of domain, so the answer is
/// read here instead of being parsed and thrown away.
///
/// It reads one doubt and returns one value, or null when the words carry nothing
/// for it. A null is not a failure to report: it leaves the doubt standing, the
/// session asks again, and the merchant can still say it differently or go to the
/// screens. What this service must never do is guess, so an answer that names no
/// product, no number and no agreement gives null rather than a plausible default.
final class AnswerReading {
  const AnswerReading({
    required this.normalizer,
    required this.numbers,
    required this.products,
  });

  final TextNormalizer normalizer;
  final FrenchNumberParser numbers;
  final SpokenProductResolver products;

  /// The value [utterance] carries for the doubt [asked], or null when it carries
  /// nothing.
  ///
  /// The value keeps the shape the completion expects: a [ProductSnapshot] for a
  /// product, a number for a quantity, a bool for a yes or a no.
  Object? read(String utterance, {required DoubtKind asked}) {
    final NormalizedText text = normalizer.normalize(utterance);
    if (text.isEmpty) {
      return null;
    }
    if (asked.answersByYesOrNo) {
      return _readsAgreement(text.tokens);
    }
    if (asked.answersByQuantity) {
      return _readsQuantity(text.tokens);
    }
    if (asked.answersByProduct) {
      return _readsProduct(text);
    }
    return null;
  }

  /// Whether the answer accepts what was read back.
  ///
  /// Only a yes settles a confirmation. A refusal and words that mean nothing here
  /// are the same thing to the session, which is right: neither of them is consent
  /// to record a sale, and treating gibberish as a no is the safe reading.
  bool _readsAgreement(List<String> tokens) =>
      tokens.any(kAffirmativeWords.contains);

  /// The first number said, wherever it comes in the answer.
  ///
  /// Only a number answers a quantity, and only the first one is read: "de" after
  /// "un" announces a partitive rather than a second quantity.
  double? _readsQuantity(List<String> tokens) {
    for (int index = 0; index < tokens.length; index += 1) {
      if (!FrenchNumberParser.isNumberToken(tokens[index])) {
        continue;
      }
      return numbers.readAt(tokens, index)?.value;
    }
    return null;
  }

  /// The product the answer names, articles dropped.
  ///
  /// An archived product is not an answer. It is out of the spoken vocabulary, and
  /// the doubt it would settle is the wrong one: naming it leaves the question
  /// standing, so the session asks again instead of completing a line the catalog
  /// forbids.
  ProductSnapshot? _readsProduct(NormalizedText text) {
    final List<String> spoken = _withoutLeadingArticles(text.tokens);
    if (spoken.isEmpty) {
      return null;
    }
    final ProductSnapshot? product = products.resolve(spoken.join(' '));
    return product != null && product.isArchived ? null : product;
  }

  List<String> _withoutLeadingArticles(List<String> tokens) {
    int first = 0;
    while (first < tokens.length && kLeadingArticles.contains(tokens[first])) {
      first += 1;
    }
    return tokens.sublist(first);
  }
}
