import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/handler_call_journal.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../catalog/in_memory_product_catalog.dart';
import '../journaling_intent_handler.dart';
import 'mock_cancel_last_sale_handler.dart';
import 'mock_query_stock_handler.dart';
import 'mock_record_restock_handler.dart';
import 'mock_record_sale_handler.dart';

/// Builds the in-memory handlers, each wrapped so every call is recorded.
///
/// Kept after the real use cases are integrated: they then remain the
/// demonstration and test doubles of the demo scenario.
VoiceHandlers buildMockVoiceHandlers({
  required InMemoryProductCatalog catalog,
  required HandlerCallJournal journal,
}) {
  return VoiceHandlers(
    recordSale: JournalingIntentHandler<SaleIntentInput, RecordSaleResult>(
      MockRecordSaleHandler(catalog),
      journal,
    ),
    recordRestock:
        JournalingIntentHandler<RestockIntentInput, RecordRestockResult>(
          MockRecordRestockHandler(catalog),
          journal,
        ),
    queryStock: JournalingIntentHandler<QueryStockInput, QueryStockResult>(
      MockQueryStockHandler(catalog),
      journal,
    ),
    cancelLastSale:
        JournalingIntentHandler<CancelLastSaleInput, CancelLastSaleResult>(
          MockCancelLastSaleHandler(catalog),
          journal,
        ),
    queryDailyStats:
        JournalingIntentHandler<QueryDailyStatsInput, QueryDailyStatsResult>(
          MockQueryDailyStatsHandler(),
          journal,
        ),
    queryLowStock:
        JournalingIntentHandler<QueryLowStockInput, QueryLowStockResult>(
          MockQueryLowStockHandler(catalog),
          journal,
        ),
    queryProductPrice:
        JournalingIntentHandler<
          QueryProductPriceInput,
          QueryProductPriceResult
        >(MockQueryProductPriceHandler(catalog), journal),
    recordStockOut:
        JournalingIntentHandler<RecordStockOutInput, RecordStockOutResult>(
          MockRecordStockOutHandler(catalog),
          journal,
        ),
    navigateToPage:
        JournalingIntentHandler<NavigateToPageInput, NavigateToPageResult>(
          MockNavigateHandler(),
          journal,
        ),
    exportSalesReport:
        JournalingIntentHandler<
          ExportSalesReportInput,
          ExportSalesReportResult
        >(MockExportReportHandler(), journal),
    createProduct:
        JournalingIntentHandler<CreateProductInput, CreateProductResult>(
          MockCreateProductHandler(catalog),
          journal,
        ),
    updateProductPrice:
        JournalingIntentHandler<
          UpdateProductPriceInput,
          UpdateProductPriceResult
        >(MockUpdateProductPriceHandler(catalog), journal),
    querySalesHistory:
        JournalingIntentHandler<
          QuerySalesHistoryInput,
          QuerySalesHistoryResult
        >(MockQuerySalesHistoryHandler(), journal),
    queryBusinessInfo:
        JournalingIntentHandler<
          QueryBusinessInfoInput,
          QueryBusinessInfoResult
        >(MockQueryBusinessInfoHandler(catalog), journal),
  );
}

final class MockQueryDailyStatsHandler implements QueryDailyStatsHandler {
  @override
  String get intentId => 'query_daily_stats';

  @override
  Future<Result<QueryDailyStatsResult>> execute(
    CommandContext context,
    QueryDailyStatsInput input,
  ) async {
    return Success<QueryDailyStatsResult>((
      date: context.dateTime,
      salesCount: 14,
      totalRevenue: 48500.0,
      totalProfit: 12500.0,
      itemsSold: 28,
    ));
  }
}

final class MockQueryLowStockHandler implements QueryLowStockHandler {
  MockQueryLowStockHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'query_low_stock';

  @override
  Future<Result<QueryLowStockResult>> execute(
    CommandContext context,
    QueryLowStockInput input,
  ) async {
    final List<ProductSnapshot> active = await catalog.readActiveProducts();
    final List<LowStockItemResult> low = <LowStockItemResult>[];
    for (final ProductSnapshot p in active) {
      if (p.stock <= p.alertThreshold) {
        low.add((
          productId: p.id,
          name: p.name,
          stock: p.stock,
          unit: p.unit,
          alertThreshold: p.alertThreshold,
          alertLevel: p.stock <= 0 ? 'out_of_stock' : 'rupture',
        ));
      }
    }
    return Success<QueryLowStockResult>((products: low));
  }
}

final class MockQueryProductPriceHandler implements QueryProductPriceHandler {
  MockQueryProductPriceHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'query_product_price';

  @override
  Future<Result<QueryProductPriceResult>> execute(
    CommandContext context,
    QueryProductPriceInput input,
  ) async {
    final ProductSnapshot? p = catalog.productById(input.productId);
    if (p == null) {
      return Failed<QueryProductPriceResult>(
        UnknownProduct(productId: input.productId),
      );
    }
    return Success<QueryProductPriceResult>((
      productId: p.id,
      productName: p.name,
      price: p.price,
      purchasePrice: p.purchasePrice,
      unit: p.unit,
    ));
  }
}

final class MockRecordStockOutHandler implements RecordStockOutHandler {
  MockRecordStockOutHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'record_stock_out';

  @override
  Future<Result<RecordStockOutResult>> execute(
    CommandContext context,
    RecordStockOutInput input,
  ) async {
    final ProductSnapshot? p = catalog.productById(input.productId);
    if (p == null) {
      return Failed<RecordStockOutResult>(
        UnknownProduct(productId: input.productId),
      );
    }
    return Success<RecordStockOutResult>((
      movementId: '${context.commandId}-out',
      productId: p.id,
      productName: p.name,
      qty: input.qty,
      reason: input.reason,
      resultingStock: p.stock - input.qty,
    ));
  }
}

final class MockNavigateHandler implements NavigateToPageHandler {
  @override
  String get intentId => 'navigate_to_page';

  @override
  Future<Result<NavigateToPageResult>> execute(
    CommandContext context,
    NavigateToPageInput input,
  ) async {
    return Success<NavigateToPageResult>((
      destination: input.destination,
      label: input.destination,
    ));
  }
}

final class MockExportReportHandler implements ExportSalesReportHandler {
  @override
  String get intentId => 'export_sales_report';

  @override
  Future<Result<ExportSalesReportResult>> execute(
    CommandContext context,
    ExportSalesReportInput input,
  ) async {
    return Success<ExportSalesReportResult>((
      format: input.format,
      filePath: '/tmp/export.${input.format}',
      salesCount: 8,
    ));
  }
}

final class MockCreateProductHandler implements CreateProductHandler {
  MockCreateProductHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'create_product';

  @override
  Future<Result<CreateProductResult>> execute(
    CommandContext context,
    CreateProductInput input,
  ) async {
    return Success<CreateProductResult>((
      productId: 'p_mock_${context.commandId}',
      name: input.name,
      price: input.price,
      purchasePrice: input.purchasePrice,
      initialQuantity: input.initialQty ?? 0,
      unit: input.unit ?? 'PIECE',
    ));
  }
}

final class MockUpdateProductPriceHandler implements UpdateProductPriceHandler {
  MockUpdateProductPriceHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'update_product_price';

  @override
  Future<Result<UpdateProductPriceResult>> execute(
    CommandContext context,
    UpdateProductPriceInput input,
  ) async {
    final ProductSnapshot? p = catalog.productById(input.productId);
    if (p == null) {
      return Failed<UpdateProductPriceResult>(
        UnknownProduct(productId: input.productId),
      );
    }
    return Success<UpdateProductPriceResult>((
      productId: p.id,
      productName: p.name,
      oldPrice: p.price,
      newPrice: input.newPrice,
    ));
  }
}

final class MockQuerySalesHistoryHandler implements QuerySalesHistoryHandler {
  @override
  String get intentId => 'query_sales_history';

  @override
  Future<Result<QuerySalesHistoryResult>> execute(
    CommandContext context,
    QuerySalesHistoryInput input,
  ) async {
    return Success<QuerySalesHistoryResult>((
      sales: <SaleHistoryItemResult>[
        (
          saleId: 'sale-1',
          dateTime: context.dateTime,
          total: 1500,
          itemsCount: 2,
        ),
        (
          saleId: 'sale-2',
          dateTime: context.dateTime,
          total: 3000,
          itemsCount: 1,
        ),
      ],
    ));
  }
}

final class MockQueryBusinessInfoHandler implements QueryBusinessInfoHandler {
  MockQueryBusinessInfoHandler(this.catalog);
  final InMemoryProductCatalog catalog;

  @override
  String get intentId => 'query_business_info';

  @override
  Future<Result<QueryBusinessInfoResult>> execute(
    CommandContext context,
    QueryBusinessInfoInput input,
  ) async {
    final List<ProductSnapshot> active = await catalog.readActiveProducts();
    return Success<QueryBusinessInfoResult>((
      storeName: 'KioskMind Mock',
      activeProductsCount: active.length,
      totalSalesCount: 10,
    ));
  }
}
