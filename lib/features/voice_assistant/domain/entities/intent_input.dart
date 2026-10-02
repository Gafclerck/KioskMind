import 'slot.dart';

/// Base class of every intent input.
///
/// [toArguments] projects the input onto the comparable argument map kept in the
/// call journal. That map is what the routing metric compares with the golden
/// set, so it must contain only what determines the call: no identifier
/// generated at runtime, no date, no displayable text.
sealed class IntentInput {
  const IntentInput();

  Map<String, Object?> toArguments();
}

/// `record_sale` input. One entry per article, in spoken order.
final class SaleIntentInput extends IntentInput {
  const SaleIntentInput({required this.items});

  final List<SaleIntentLine> items;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{
      'items': <Map<String, Object?>>[
        for (final SaleIntentLine line in items) line.toArguments(),
      ],
    };
  }
}

final class SaleIntentLine {
  const SaleIntentLine({
    required this.productId,
    required this.productName,
    required this.qty,
    this.spokenUnitPrice,
  });

  /// Resolved by the application, never invented by a language model (D5).
  final String productId;

  /// Copied into the sale line so history survives a later rename.
  final String productName;

  /// Quantity expressed in the product's own unit.
  final double qty;

  /// Price spoken by the merchant. A doubt signal only: the catalog price is
  /// applied, the gap above 20 percent raises a confirmation (contract A7).
  final double? spokenUnitPrice;

  Map<String, Object?> toArguments() {
    return <String, Object?>{kProductIdSlot: productId, 'qty': qty};
  }
}

/// `record_restock` input. One entry per article, in spoken order.
final class RestockIntentInput extends IntentInput {
  const RestockIntentInput({required this.items});

  final List<RestockIntentLine> items;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{
      'items': <Map<String, Object?>>[
        for (final RestockIntentLine line in items) line.toArguments(),
      ],
    };
  }
}

final class RestockIntentLine {
  const RestockIntentLine({
    required this.productId,
    required this.productName,
    required this.qty,
    this.spokenUnitCost,
  });

  final String productId;
  final String productName;

  /// Quantity expressed in the product's own unit. Must be positive.
  final double qty;

  /// Purchase cost of this movement when the merchant announced it. Null
  /// leaves the margin of the line unknown (contract A8).
  final double? spokenUnitCost;

  Map<String, Object?> toArguments() {
    return <String, Object?>{
      kProductIdSlot: productId,
      'qty': qty,
      if (spokenUnitCost != null) 'unitCost': spokenUnitCost,
    };
  }
}

/// `query_stock` input. The product is resolved before the call.
final class QueryStockInput extends IntentInput {
  const QueryStockInput({required this.productId});

  final String productId;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{kProductIdSlot: productId};
  }
}

/// `cancel_last_sale` input. The session voice owns the identifier: the intent
/// has no slot, so a cancellation can only target the sale just made (A12).
final class CancelLastSaleInput extends IntentInput {
  const CancelLastSaleInput({required this.saleId});

  final String saleId;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{'saleId': saleId};
  }
}
