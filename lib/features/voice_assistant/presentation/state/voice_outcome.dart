import '../../../../core/usecase/result.dart';
import '../../domain/entities/fact_result.dart';
import '../../domain/entities/intent_result.dart';
import '../../domain/usecases/execute_command.dart';

/// One line of a recap, as the merchant is told about it.
///
/// [unit] is the code the catalog uses, and null when the use case that wrote the
/// line did not report one: the contract of a restock carries no unit, and a recap
/// invents nothing.
///
/// [unitPrice] is the price the line was actually valued at, and null when the use
/// case that wrote the line reported none: a restock carries a cost the merchant
/// never sees, and a price invented here would be a figure on a receipt that no
/// sale produced. It is the price the handler applied and not the catalog's, so a
/// line priced by an amount the merchant announced reads back as that amount.
typedef VoiceRecapLine = ({String name, double qty, String? unit, double? unitPrice});

/// What a command actually did, in the shape a recap needs.
///
/// The domain already returns exactly what happened, per intent. What it does not
/// return is one type: a screen cannot switch over four record types without
/// knowing each intent's shape, and a switch per intent in every widget is a rule
/// written three times. This is that one place, and it is presentation: it adds
/// no fact, it only reads the ones the handler reported.
sealed class VoiceOutcome {
  const VoiceOutcome();
}

/// Lines were sold, and the session may undo them.
final class SaleRecorded extends VoiceOutcome {
  const SaleRecorded({required this.lines, required this.total});

  final List<VoiceRecapLine> lines;

  /// Total in francs, read in words because a synthesiser reads "1250" badly.
  final double total;
}

/// Stock was added. Nothing to undo: the cancellation handler knows sales only.
final class RestockRecorded extends VoiceOutcome {
  const RestockRecorded(this.lines);

  final List<VoiceRecapLine> lines;
}

/// The stock of one product was read.
final class StockRead extends VoiceOutcome {
  const StockRead({
    required this.product,
    required this.stock,
    required this.unit,
  });

  final String product;

  final double stock;

  final String unit;
}

/// The sale of the undo window was cancelled and its stock given back.
final class SaleCancelled extends VoiceOutcome {
  const SaleCancelled(this.lines);

  final List<VoiceRecapLine> lines;
}

/// Daily sales stats outcome.
final class DailyStatsRead extends VoiceOutcome {
  const DailyStatsRead({
    required this.salesCount,
    required this.totalRevenue,
    required this.totalProfit,
    required this.itemsSold,
  });

  final int salesCount;
  final double totalRevenue;
  final double totalProfit;
  final int itemsSold;
}

/// Low stock alerts outcome.
final class LowStockRead extends VoiceOutcome {
  const LowStockRead(this.products);

  final List<LowStockItemResult> products;
}

/// Product price query outcome.
final class ProductPriceRead extends VoiceOutcome {
  const ProductPriceRead({
    required this.product,
    required this.price,
    this.purchasePrice,
    required this.unit,
  });

  final String product;
  final double price;
  final double? purchasePrice;
  final String unit;
}

/// Stock out recorded outcome.
final class StockOutRecorded extends VoiceOutcome {
  const StockOutRecorded({
    required this.product,
    required this.qty,
    required this.reason,
    required this.resultingStock,
  });

  final String product;
  final double qty;
  final String reason;
  final double resultingStock;
}

/// Page navigated outcome.
final class PageNavigated extends VoiceOutcome {
  const PageNavigated(this.label);

  final String label;
}

/// Report exported outcome.
final class ReportExported extends VoiceOutcome {
  const ReportExported({required this.format, required this.salesCount});

  final String format;
  final int salesCount;
}

/// Product created outcome.
final class ProductCreated extends VoiceOutcome {
  const ProductCreated({
    required this.name,
    required this.price,
    required this.initialQuantity,
    required this.unit,
  });

  final String name;
  final double price;
  final double initialQuantity;
  final String unit;
}

/// Product price updated outcome.
final class ProductPriceUpdated extends VoiceOutcome {
  const ProductPriceUpdated({
    required this.product,
    required this.oldPrice,
    required this.newPrice,
  });

  final String product;
  final double oldPrice;
  final double newPrice;
}

/// Sales history read outcome.
final class SalesHistoryRead extends VoiceOutcome {
  const SalesHistoryRead(this.sales);

  final List<SaleHistoryItemResult> sales;
}

/// Business info read outcome.
final class BusinessInfoRead extends VoiceOutcome {
  const BusinessInfoRead({
    required this.storeName,
    required this.activeProductsCount,
    required this.totalSalesCount,
  });

  final String storeName;
  final int activeProductsCount;
  final int totalSalesCount;
}

/// What [execution] did, or null when it did not run a handler.
///
/// Null covers both "held" and "failed": in those two cases what the merchant is
/// told is about the doubt, not about a result, and the doubt is what the caller
/// already has.
VoiceOutcome? outcomeOf(CommandExecution execution) {
  if (execution is! ExecutedCommand) {
    return null;
  }
  return switch (execution.result) {
    Failed<Object>() => null,
    Success<Object>(value: final Object value) => outcomeOfValue(value),
  };
}

/// The outcome of one handler answer, or null for a shape nobody knows.
///
/// A handler this module has no use case for would land here, and the null keeps
/// it out of the recap rather than printing a record the merchant cannot read.
VoiceOutcome? outcomeOfValue(Object value) {
  return switch (value) {
    final RecordSaleResult result => SaleRecorded(
      lines: _saleLines(result.lines),
      total: result.total,
    ),
    final RecordRestockResult result => RestockRecorded(<VoiceRecapLine>[
      for (final RestockLineResult line in result.lines)
        // A restock carries a purchase cost, not a selling price: there is no
        // receipt here for a price to have been applied to.
        (name: line.name, qty: line.qty, unit: null, unitPrice: null),
    ]),
    final QueryStockResult result => StockRead(
      product: result.productName,
      stock: result.stock,
      unit: result.unit,
    ),
    final CancelLastSaleResult result => SaleCancelled(
      _saleLines(result.restored),
    ),
    final QueryDailyStatsResult result => DailyStatsRead(
      salesCount: result.salesCount,
      totalRevenue: result.totalRevenue,
      totalProfit: result.totalProfit,
      itemsSold: result.itemsSold,
    ),
    final QueryLowStockResult result => LowStockRead(result.products),
    final QueryProductPriceResult result => ProductPriceRead(
      product: result.productName,
      price: result.price,
      purchasePrice: result.purchasePrice,
      unit: result.unit,
    ),
    final RecordStockOutResult result => StockOutRecorded(
      product: result.productName,
      qty: result.qty,
      reason: result.reason,
      resultingStock: result.resultingStock,
    ),
    final NavigateToPageResult result => PageNavigated(result.label),
    final ExportSalesReportResult result => ReportExported(
      format: result.format,
      salesCount: result.salesCount,
    ),
    final CreateProductResult result => ProductCreated(
      name: result.name,
      price: result.price,
      initialQuantity: result.initialQuantity,
      unit: result.unit,
    ),
    final UpdateProductPriceResult result => ProductPriceUpdated(
      product: result.productName,
      oldPrice: result.oldPrice,
      newPrice: result.newPrice,
    ),
    final QuerySalesHistoryResult result => SalesHistoryRead(result.sales),
    final QueryBusinessInfoResult result => BusinessInfoRead(
      storeName: result.storeName,
      activeProductsCount: result.activeProductsCount,
      totalSalesCount: result.totalSalesCount,
    ),
    _ => null,
  };
}

List<VoiceRecapLine> _saleLines(List<SaleLineResult> lines) {
  return <VoiceRecapLine>[
    for (final SaleLineResult line in lines)
      (
        name: line.name,
        qty: line.qty,
        unit: line.unit,
        unitPrice: line.appliedUnitPrice,
      ),
  ];
}

extension VoiceOutcomeToFactResult on VoiceOutcome {
  /// Converts this presentation outcome to verifiable structured facts.
  FactResult toFactResult() {
    return switch (this) {
      final SaleRecorded sale => FactResult(
        operation: 'record_sale',
        data: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            for (final VoiceRecapLine line in sale.lines)
              <String, dynamic>{
                'product': line.name,
                'qty': line.qty,
                'unit': line.unit,
              },
          ],
          'total': sale.total,
          'currency': 'francs',
        },
      ),
      final RestockRecorded restock => FactResult(
        operation: 'record_restock',
        data: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            for (final VoiceRecapLine line in restock.lines)
              <String, dynamic>{
                'product': line.name,
                'qty': line.qty,
                'unit': line.unit,
              },
          ],
        },
      ),
      final StockRead stock => FactResult(
        operation: 'query_stock',
        data: <String, dynamic>{
          'product': stock.product,
          'stock': stock.stock,
          'unit': stock.unit,
        },
      ),
      final SaleCancelled cancelled => FactResult(
        operation: 'cancel_last_sale',
        data: <String, dynamic>{
          'restored': <Map<String, dynamic>>[
            for (final VoiceRecapLine line in cancelled.lines)
              <String, dynamic>{
                'product': line.name,
                'qty': line.qty,
                'unit': line.unit,
              },
          ],
        },
      ),
      final DailyStatsRead stats => FactResult(
        operation: 'query_daily_stats',
        data: <String, dynamic>{
          'salesCount': stats.salesCount,
          'totalRevenue': stats.totalRevenue,
          'totalProfit': stats.totalProfit,
          'itemsSold': stats.itemsSold,
        },
      ),
      final LowStockRead lowStock => FactResult(
        operation: 'query_low_stock',
        data: <String, dynamic>{
          'products': <Map<String, dynamic>>[
            for (final LowStockItemResult p in lowStock.products)
              <String, dynamic>{
                'productId': p.productId,
                'name': p.name,
                'stock': p.stock,
                'alertThreshold': p.alertThreshold,
                'unit': p.unit,
              },
          ],
        },
      ),
      final ProductPriceRead price => FactResult(
        operation: 'query_product_price',
        data: <String, dynamic>{
          'product': price.product,
          'price': price.price,
          if (price.purchasePrice != null) 'purchasePrice': price.purchasePrice,
          'unit': price.unit,
        },
      ),
      final StockOutRecorded stockOut => FactResult(
        operation: 'record_stock_out',
        data: <String, dynamic>{
          'product': stockOut.product,
          'qty': stockOut.qty,
          'reason': stockOut.reason,
          'resultingStock': stockOut.resultingStock,
        },
      ),
      final PageNavigated nav => FactResult(
        operation: 'navigate_to_page',
        data: <String, dynamic>{'label': nav.label},
      ),
      final ReportExported rep => FactResult(
        operation: 'export_sales_report',
        data: <String, dynamic>{
          'format': rep.format,
          'salesCount': rep.salesCount,
        },
      ),
      final ProductCreated prod => FactResult(
        operation: 'create_product',
        data: <String, dynamic>{
          'name': prod.name,
          'price': prod.price,
          'initialQuantity': prod.initialQuantity,
          'unit': prod.unit,
        },
      ),
      final ProductPriceUpdated pupd => FactResult(
        operation: 'update_product_price',
        data: <String, dynamic>{
          'product': pupd.product,
          'oldPrice': pupd.oldPrice,
          'newPrice': pupd.newPrice,
        },
      ),
      final SalesHistoryRead hist => FactResult(
        operation: 'query_sales_history',
        data: <String, dynamic>{
          'sales': <Map<String, dynamic>>[
            for (final SaleHistoryItemResult s in hist.sales)
              <String, dynamic>{
                'saleId': s.saleId,
                'dateTime': s.dateTime.toIso8601String(),
                'itemsCount': s.itemsCount,
                'total': s.total,
              },
          ],
        },
      ),
      final BusinessInfoRead info => FactResult(
        operation: 'query_business_info',
        data: <String, dynamic>{
          'storeName': info.storeName,
          'activeProductsCount': info.activeProductsCount,
          'totalSalesCount': info.totalSalesCount,
        },
      ),
    };
  }
}
