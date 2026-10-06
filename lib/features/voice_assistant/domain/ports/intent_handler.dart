import '../../../../core/usecase/result.dart';
import '../entities/intent_input.dart';
import '../entities/intent_result.dart';
import 'command_context.dart';

/// Port of a business use case the voice module can call.
///
/// One handler per intent, and one intent per handler. Implementations live in
/// `data/handlers`: in-memory mocks now, real use cases in phase I. The voice
/// module never sees a Firestore document.
abstract interface class IntentHandler<TInput extends IntentInput, TOutput> {
  /// Must match the `handler` of an entry in `voice/intent_catalog.json`.
  String get intentId;

  Future<Result<TOutput>> execute(CommandContext context, TInput input);
}

/// The intent the session voice owns the identifier of.
///
/// Named here because the intent carries no slot: the sale it targets comes from the
/// undo window, and the binding in `data/commands/voice_bindings.dart` is where that
/// is turned into a call.
const String kCancelLastSaleIntent = 'cancel_last_sale';

/// Offline-supported intents for core kiosk cashier transactions.
const Set<String> kCoreOfflineIntentIds = <String>{
  'record_sale',
  'record_restock',
  'query_stock',
  kCancelLastSaleIntent,
};

/// Online-only tool intents.
const Set<String> kOnlineOnlyIntentIds = <String>{
  'query_daily_stats',
  'query_low_stock',
  'query_product_price',
  'record_stock_out',
  'navigate_to_page',
  'export_sales_report',
  'create_product',
  'update_product_price',
  'query_sales_history',
  'query_business_info',
};

/// Every intent the module can route, in catalog order.
///
/// The catalog validates its `handler` values against this set, so a command
/// cannot be described in `voice/intent_catalog.json` without a port able to
/// execute it.
const Set<String> kSupportedIntentIds = <String>{
  ...kCoreOfflineIntentIds,
  ...kOnlineOnlyIntentIds,
};

typedef RecordSaleHandler = IntentHandler<SaleIntentInput, RecordSaleResult>;
typedef RecordRestockHandler =
    IntentHandler<RestockIntentInput, RecordRestockResult>;

typedef QueryStockHandler = IntentHandler<QueryStockInput, QueryStockResult>;

typedef CancelLastSaleHandler =
    IntentHandler<CancelLastSaleInput, CancelLastSaleResult>;

typedef QueryDailyStatsHandler =
    IntentHandler<QueryDailyStatsInput, QueryDailyStatsResult>;

typedef QueryLowStockHandler =
    IntentHandler<QueryLowStockInput, QueryLowStockResult>;

typedef QueryProductPriceHandler =
    IntentHandler<QueryProductPriceInput, QueryProductPriceResult>;

typedef RecordStockOutHandler =
    IntentHandler<RecordStockOutInput, RecordStockOutResult>;

typedef NavigateToPageHandler =
    IntentHandler<NavigateToPageInput, NavigateToPageResult>;

typedef ExportSalesReportHandler =
    IntentHandler<ExportSalesReportInput, ExportSalesReportResult>;

typedef CreateProductHandler =
    IntentHandler<CreateProductInput, CreateProductResult>;

typedef UpdateProductPriceHandler =
    IntentHandler<UpdateProductPriceInput, UpdateProductPriceResult>;

typedef QuerySalesHistoryHandler =
    IntentHandler<QuerySalesHistoryInput, QuerySalesHistoryResult>;

typedef QueryBusinessInfoHandler =
    IntentHandler<QueryBusinessInfoInput, QueryBusinessInfoResult>;

/// The handler ports the executor may call, at most one per intent.
///
/// A holder rather than a heterogeneous list: a `List<IntentHandler<dynamic,
/// dynamic>>` would erase the input and output types that make each call site
/// checkable.
final class VoiceHandlers {
  const VoiceHandlers({
    this.recordSale,
    this.recordRestock,
    this.queryStock,
    this.cancelLastSale,
    this.queryDailyStats,
    this.queryLowStock,
    this.queryProductPrice,
    this.recordStockOut,
    this.navigateToPage,
    this.exportSalesReport,
    this.createProduct,
    this.updateProductPrice,
    this.querySalesHistory,
    this.queryBusinessInfo,
  });

  final RecordSaleHandler? recordSale;
  final RecordRestockHandler? recordRestock;
  final QueryStockHandler? queryStock;
  final CancelLastSaleHandler? cancelLastSale;
  final QueryDailyStatsHandler? queryDailyStats;
  final QueryLowStockHandler? queryLowStock;
  final QueryProductPriceHandler? queryProductPrice;
  final RecordStockOutHandler? recordStockOut;
  final NavigateToPageHandler? navigateToPage;
  final ExportSalesReportHandler? exportSalesReport;
  final CreateProductHandler? createProduct;
  final UpdateProductPriceHandler? updateProductPrice;
  final QuerySalesHistoryHandler? querySalesHistory;
  final QueryBusinessInfoHandler? queryBusinessInfo;
}
