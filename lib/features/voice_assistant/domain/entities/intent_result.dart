/// Output of a single sale line.
///
/// Carries the name, the unit and the resulting stock so the spoken recap
/// needs nothing else, and so a negative stock is detected without reading the
/// catalog again (D10). Declared as a record so the shared contract suite
/// compares mock and real results structurally, with no equality method to
/// drift.
typedef SaleLineResult = ({
  String productId,
  String name,
  String unit,
  double qty,
  double appliedUnitPrice,
  double resultingStock,
});

typedef RecordSaleResult = ({
  String saleId,
  double total,
  List<SaleLineResult> lines,
});

typedef RestockLineResult = ({
  String productId,
  String name,
  double qty,
  double? appliedUnitCost,
  double resultingStock,
});

typedef RecordRestockResult = ({
  List<String> movementIds,
  List<RestockLineResult> lines,
});

typedef QueryStockResult = ({
  String productId,
  String productName,
  double stock,
  String unit,
  double? alertThreshold,
});

typedef CancelLastSaleResult = ({String saleId, List<SaleLineResult> restored});
