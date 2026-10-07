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

/// `query_daily_stats` input.
final class QueryDailyStatsInput extends IntentInput {
  const QueryDailyStatsInput({this.date});

  final String? date;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{if (date != null) 'date': date};
  }
}

/// `query_low_stock` input.
final class QueryLowStockInput extends IntentInput {
  const QueryLowStockInput({this.level});

  final String? level;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{if (level != null) 'level': level};
  }
}

/// `query_product_price` input.
final class QueryProductPriceInput extends IntentInput {
  const QueryProductPriceInput({required this.productId});

  final String productId;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{kProductIdSlot: productId};
  }
}

/// `record_stock_out` input.
final class RecordStockOutInput extends IntentInput {
  const RecordStockOutInput({
    required this.productId,
    required this.qty,
    required this.reason,
    this.note,
  });

  final String productId;
  final double qty;
  final String reason;
  final String? note;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{
      kProductIdSlot: productId,
      'qty': qty,
      'reason': reason,
      if (note != null) 'note': note,
    };
  }
}

/// `navigate_to_page` input.
final class NavigateToPageInput extends IntentInput {
  const NavigateToPageInput({required this.destination});

  final String destination;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{'destination': destination};
  }
}

/// `export_sales_report` input.
final class ExportSalesReportInput extends IntentInput {
  const ExportSalesReportInput({required this.format, this.period});

  final String format;
  final String? period;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{
      'format': format,
      if (period != null) 'period': period,
    };
  }
}

/// `create_product` input.
final class CreateProductInput extends IntentInput {
  const CreateProductInput({
    required this.name,
    required this.price,
    this.purchasePrice,
    this.initialQty,
    this.category,
    this.unit,
  });

  final String name;
  final double price;
  final double? purchasePrice;
  final double? initialQty;
  final String? category;
  final String? unit;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{
      'name': name,
      'price': price,
      if (purchasePrice != null) 'purchasePrice': purchasePrice,
      if (initialQty != null) 'initialQty': initialQty,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
    };
  }
}

/// `update_product_price` input.
final class UpdateProductPriceInput extends IntentInput {
  const UpdateProductPriceInput({
    required this.productId,
    required this.newPrice,
  });

  final String productId;
  final double newPrice;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{kProductIdSlot: productId, 'newPrice': newPrice};
  }
}

/// `query_sales_history` input.
final class QuerySalesHistoryInput extends IntentInput {
  const QuerySalesHistoryInput({this.limit});

  final int? limit;

  @override
  Map<String, Object?> toArguments() {
    return <String, Object?>{if (limit != null) 'limit': limit};
  }
}

/// `query_business_info` input.
final class QueryBusinessInfoInput extends IntentInput {
  const QueryBusinessInfoInput();

  @override
  Map<String, Object?> toArguments() => const <String, Object?>{};
}
