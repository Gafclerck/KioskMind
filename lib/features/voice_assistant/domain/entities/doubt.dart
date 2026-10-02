import 'product_snapshot.dart';

/// Why a proposal is not ready to execute.
///
/// A doubt is a fact about what was said, never a displayable message: the text
/// the merchant reads is produced later from this kind, in his language.
enum DoubtKind {
  /// The utterance names no product at all.
  missingProduct,

  /// A name was spoken but matches no product in the catalog.
  unknownProduct,

  /// Several products fit the words that were said.
  ambiguousProduct,

  /// The product exists but is archived, so it is out of the spoken vocabulary.
  archivedProduct,

  /// The line names a product but no quantity, as in "vendu du sucre".
  missingQuantity,

  /// The quantity is zero or negative.
  invalidQuantity,

  /// The quantity points at something relative to an earlier utterance or to
  /// the shop's habits, which a single utterance cannot resolve.
  undeterminedQuantity,

  /// The quantity is far from what this merchant usually sells.
  implausibleQuantity,

  /// The announced amount differs from the catalog price or cost.
  amountMismatch,

  /// The words point at something already said ("le meme", "celle-la").
  anaphora,

  /// The command is a real command but outside what this module may do.
  outOfScope,

  /// The words ask for something destructive, which voice may never do.
  destructiveRequest,

  /// The utterance is about the whole shop rather than one command.
  unboundedScope,

  /// The utterance matches no command in the catalog.
  outOfDomain,

  /// The utterance describes an order, and no use case handles orders.
  noOrderUseCase,
}

/// What was understood of a line that is not complete.
///
/// Both fields are null when nothing of the line was understood. A doubt carries
/// this because a doubt is a fact about what was said: the merchant who said
/// "vendu deux huiles" has said two, and asking which oil must not lose it.
typedef PartialLine = ({ProductSnapshot? product, double? qty});

/// A doubt attached to a proposal.
final class Doubt {
  const Doubt({
    required this.kind,
    this.slotName,
    this.candidates = const <ProductSnapshot>[],
    this.partial,
  });

  const Doubt.missingProduct() : this(kind: DoubtKind.missingProduct);

  final DoubtKind kind;

  /// Slot the doubt is about, when it concerns one line only.
  final String? slotName;

  /// Products that fit equally well, for [DoubtKind.ambiguousProduct].
  final List<ProductSnapshot> candidates;

  /// What the merchant said about the incomplete line, so that answering the
  /// question completes that line instead of replacing it.
  final PartialLine? partial;

  @override
  String toString() =>
      'Doubt(${kind.name}${slotName == null ? '' : ', $slotName'})';
}
