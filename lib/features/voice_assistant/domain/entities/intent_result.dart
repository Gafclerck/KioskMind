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

typedef QueryDailyStatsResult = ({
  DateTime date,
  int salesCount,
  double totalRevenue,
  double totalProfit,
  int itemsSold,
});

typedef LowStockItemResult = ({
  String productId,
  String name,
  double stock,
  String unit,
  double alertThreshold,
  String alertLevel,
});

typedef QueryLowStockResult = ({List<LowStockItemResult> products});

typedef QueryProductPriceResult = ({
  String productId,
  String productName,
  double price,
  double? purchasePrice,
  String unit,
});

typedef RecordStockOutResult = ({
  String movementId,
  String productId,
  String productName,
  double qty,
  String reason,
  double resultingStock,
});

typedef NavigateToPageResult = ({String destination, String label});

typedef ExportSalesReportResult = ({
  String format,
  String filePath,
  int salesCount,
});

typedef CreateProductResult = ({
  String productId,
  String name,
  double price,
  double? purchasePrice,
  double initialQuantity,
  String unit,
});

typedef UpdateProductPriceResult = ({
  String productId,
  String productName,
  double oldPrice,
  double newPrice,
});

typedef SaleHistoryItemResult = ({
  String saleId,
  DateTime dateTime,
  double total,
  int itemsCount,
});

typedef QuerySalesHistoryResult = ({List<SaleHistoryItemResult> sales});

typedef QueryBusinessInfoResult = ({
  String storeName,
  int activeProductsCount,
  int totalSalesCount,
});
