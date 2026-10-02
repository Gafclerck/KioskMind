import '../entities/command_proposal.dart';
import '../entities/doubt.dart';
import '../entities/slot.dart';
import '../entities/voice_config.dart';

/// The checks that need the catalog: what was said has to be plausible for a
/// shop selling these products.
///
/// A parser cannot do this. "trente sucre" is a well formed number and an absurd
/// quantity for a shop that sells six a day; only the product knows. So the
/// validator reads the catalog values the extractor already carried in the lines
/// and turns what does not fit into doubts.
///
/// It adds doubts and never rewrites the proposal: a quantity it considers
/// impossible is not replaced by a plausible one, because the module has no way to
/// know which number was meant. It also never returns the parser's own doubts, so
/// the caller keeps both and can tell where each came from.
final class CommandValidator {
  const CommandValidator({required this.config});

  final VoiceConfig config;

  /// The doubts [proposal] raises on its own, in proposal order.
  List<Doubt> validate(CommandProposal proposal) {
    final List<ItemMention> lines =
        proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
        const <ItemMention>[];
    return <Doubt>[
      for (final ItemMention line in lines) ..._lineDoubts(line, proposal),
    ];
  }

  List<Doubt> _lineDoubts(ItemMention line, CommandProposal proposal) {
    final Doubt? quantity = _quantityDoubt(line);
    final Doubt? amount = _amountDoubt(line, proposal.intentId);
    return <Doubt>[?quantity, ?amount];
  }

  /// The quantity doubts of one line, at most one.
  ///
  /// A quantity past the ceiling is not an unusual quantity but no quantity at
  /// all, so the two are exclusive: reporting both would make the dialogue offer
  /// to confirm a number that cannot be confirmed.
  Doubt? _quantityDoubt(ItemMention line) {
    if (line.qty <= 0 || line.qty > config.shopQuantityCeiling) {
      return const Doubt(kind: DoubtKind.invalidQuantity, slotName: kItemsSlot);
    }
    if (line.qty > config.unusualQuantityThreshold) {
      return const Doubt(
        kind: DoubtKind.implausibleQuantity,
        slotName: kItemsSlot,
      );
    }
    return null;
  }

  /// The price doubt of one line, when an amount was spoken.
  ///
  /// The reference is the price the intent would apply: the sale price on a sale,
  /// the purchase price on a restock. Comparing a restock to the sale price
  /// would doubt every correct restock, and comparing a sale to the purchase price
  /// would doubt the normal case, so the intent decides which price counts.
  Doubt? _amountDoubt(ItemMention line, String intentId) {
    final double? spoken = line.spokenAmount;
    final double? reference = _referencePrice(line, intentId);
    if (spoken == null || reference == null || reference <= 0) {
      return null;
    }
    final double gap = (spoken - reference).abs() / reference;
    if (gap <= config.priceToleranceRatio) {
      return null;
    }
    return const Doubt(kind: DoubtKind.amountMismatch, slotName: kItemsSlot);
  }

  double? _referencePrice(ItemMention line, String intentId) {
    return switch (intentId) {
      'record_sale' => line.product.price,
      'record_restock' => line.product.purchasePrice,
      _ => null,
    };
  }
}
