import 'product_snapshot.dart';

/// Name of the slot holding the lines of a sale or a restock.
///
/// Named here rather than written in each place: the extractor fills it, the
/// validator reads it, and the handler arguments are built from it, so a doubt
/// about "the lines" has to point at one string.
const String kItemsSlot = 'items';

/// A value read from an utterance for one slot of an intent.
///
/// A slot is either present with a value or absent. It never carries a guess:
/// when the merchant did not say it, the slot is simply not in the proposal and
/// the decision policy decides what to ask.
final class Slot {
  const Slot({required this.name, required this.value});

  final String name;
  final Object? value;

  @override
  String toString() => 'Slot($name: $value)';
}

/// One line of a sale or a restock, as the merchant said it.
///
/// [product] is always resolved by the application from the catalog: no
/// identifier is ever taken from a spoken word or from a language model.
final class ItemMention {
  const ItemMention({
    required this.product,
    required this.qty,
    this.spokenAmount,
    this.spokenUnit,
  });

  final ProductSnapshot product;

  /// Quantity in the product's own unit. Always strictly positive: a
  /// non-positive value is a doubt, never a line.
  final double qty;

  /// Amount announced for the line: a unit price on a sale, a unit cost on a
  /// restock. Null when the merchant did not say one.
  final double? spokenAmount;

  /// Unit spoken by the merchant, when it differs from the product's own.
  final String? spokenUnit;

  /// The line as the handler arguments of [intentId] see it.
  ///
  /// A spoken amount is only part of a restock. On a sale it stays a doubt: the
  /// catalog price applies and the gap is confirmed, so putting it in the
  /// arguments would make the recap show a price the sale did not use.
  Map<String, Object?> toArguments(String intentId) {
    final bool carriesAmount = intentId == 'record_restock';
    return <String, Object?>{
      'productId': product.id,
      'qty': qty,
      if (carriesAmount && spokenAmount != null) 'unitCost': spokenAmount,
    };
  }
}
