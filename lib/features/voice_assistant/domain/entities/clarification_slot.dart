import 'doubt.dart';

/// What a pending question is waiting for.
///
/// Named rather than described in prose because the frozen test set states the
/// answer slot with these exact words, so a mismatch here would be a routing error
/// and not a wording difference. `validate_golden` checks them against the same
/// list.
enum ClarificationSlot {
  /// Which product was meant, for an intent with no lines at all.
  productName('productName'),

  /// Which product the first line of a sale or a restock is about.
  itemProductName('items[0].productName'),

  /// How many of that product the first line carries.
  itemQty('items[0].qty'),

  /// Whether the merchant agrees with the recap as understood.
  confirmed('confirmed');

  const ClarificationSlot(this.code);

  final String code;

  /// The slot a doubt of that kind is answered on, or null when it is not
  /// answered by naming anything.
  ///
  /// An ambiguous or unknown product and a missing quantity all name one line
  /// when the intent has lines, and the intent decides which addressing is used.
  /// A reference to an earlier utterance ("celle-la") names no slot: the session
  /// cannot be filled in by the merchant naming something, so the session asks
  /// again and returns null rather than pretending a slot would help.
  static ClarificationSlot? forDoubt(
    DoubtKind doubt, {
    required bool hasItems,
  }) {
    return switch (doubt) {
      DoubtKind.ambiguousProduct ||
      DoubtKind.unknownProduct ||
      DoubtKind.missingProduct =>
        hasItems
            ? ClarificationSlot.itemProductName
            : ClarificationSlot.productName,
      DoubtKind.missingQuantity ||
      DoubtKind.undeterminedQuantity => ClarificationSlot.itemQty,
      _ => null,
    };
  }
}
