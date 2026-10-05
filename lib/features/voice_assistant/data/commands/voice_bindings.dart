import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/intent_input.dart';
import '../../domain/entities/intent_result.dart';
import '../../domain/entities/slot.dart';
import '../../domain/ports/command_context.dart';
import '../../domain/ports/intent_handler.dart';
import '../../domain/ports/intent_registry.dart';
import '../../domain/usecases/undo_last_command.dart';

/// The bindings of the four shipped commands.
///
/// The one place that says how a proposal becomes the typed input its handler
/// takes, and which success leaves a sale to take back. The executor, the parser and
/// the validator know none of it, which is what lets a command be added here and in
/// the catalog without touching them.
///
/// Phase I replaces this file, one binding at a time, as the real use cases land.
List<IntentBinding> buildVoiceBindings({
  required VoiceHandlers handlers,
  required UndoLastCommand undo,
}) {
  return <IntentBinding>[
    if (handlers.recordSale case final RecordSaleHandler sale)
      IntentBinding.bind<SaleIntentInput, RecordSaleResult>(
        intentId: sale.intentId,
        handler: sale,
        input: _saleInput,
        undoTarget: (RecordSaleResult result) => result.saleId,
      ),
    if (handlers.recordRestock case final RecordRestockHandler restock)
      IntentBinding.bind<RestockIntentInput, RecordRestockResult>(
        intentId: restock.intentId,
        handler: restock,
        input: _restockInput,
      ),
    if (handlers.queryStock case final QueryStockHandler query)
      IntentBinding.bind<QueryStockInput, QueryStockResult>(
        intentId: query.intentId,
        handler: query,
        input: _queryInput,
      ),
    IntentBinding.ofCall(
      intentId: kCancelLastSaleIntent,
      call: (CommandProposal proposal, CommandContext context) =>
          undo.run(source: context.source),
      undoTarget: (Object result) => null,
    ),
    if (handlers.queryDailyStats case final QueryDailyStatsHandler dailyStats)
      IntentBinding.bind<QueryDailyStatsInput, QueryDailyStatsResult>(
        intentId: dailyStats.intentId,
        handler: dailyStats,
        input: _dailyStatsInput,
      ),
    if (handlers.queryLowStock case final QueryLowStockHandler lowStock)
      IntentBinding.bind<QueryLowStockInput, QueryLowStockResult>(
        intentId: lowStock.intentId,
        handler: lowStock,
        input: _lowStockInput,
      ),
    if (handlers.queryProductPrice
        case final QueryProductPriceHandler productPrice)
      IntentBinding.bind<QueryProductPriceInput, QueryProductPriceResult>(
        intentId: productPrice.intentId,
        handler: productPrice,
        input: _productPriceInput,
      ),
    if (handlers.recordStockOut case final RecordStockOutHandler stockOut)
      IntentBinding.bind<RecordStockOutInput, RecordStockOutResult>(
        intentId: stockOut.intentId,
        handler: stockOut,
        input: _stockOutInput,
      ),
    if (handlers.navigateToPage case final NavigateToPageHandler nav)
      IntentBinding.bind<NavigateToPageInput, NavigateToPageResult>(
        intentId: nav.intentId,
        handler: nav,
        input: _navigateInput,
      ),
    if (handlers.exportSalesReport
        case final ExportSalesReportHandler exportReport)
      IntentBinding.bind<ExportSalesReportInput, ExportSalesReportResult>(
        intentId: exportReport.intentId,
        handler: exportReport,
        input: _exportReportInput,
      ),
    if (handlers.createProduct case final CreateProductHandler createProduct)
      IntentBinding.bind<CreateProductInput, CreateProductResult>(
        intentId: createProduct.intentId,
        handler: createProduct,
        input: _createProductInput,
      ),
    if (handlers.updateProductPrice
        case final UpdateProductPriceHandler updatePrice)
      IntentBinding.bind<UpdateProductPriceInput, UpdateProductPriceResult>(
        intentId: updatePrice.intentId,
        handler: updatePrice,
        input: _updatePriceInput,
      ),
    if (handlers.querySalesHistory
        case final QuerySalesHistoryHandler salesHistory)
      IntentBinding.bind<QuerySalesHistoryInput, QuerySalesHistoryResult>(
        intentId: salesHistory.intentId,
        handler: salesHistory,
        input: _salesHistoryInput,
      ),
    if (handlers.queryBusinessInfo
        case final QueryBusinessInfoHandler businessInfo)
      IntentBinding.bind<QueryBusinessInfoInput, QueryBusinessInfoResult>(
        intentId: businessInfo.intentId,
        handler: businessInfo,
        input: _businessInfoInput,
      ),
  ];
}

/// The lines of a sale, in spoken order, with the price as a doubt signal only.
Result<SaleIntentInput> _saleInput(CommandProposal proposal) {
  return Success<SaleIntentInput>(
    SaleIntentInput(
      items: <SaleIntentLine>[
        for (final ItemMention line in _items(proposal))
          SaleIntentLine(
            productId: line.product.id,
            productName: line.product.name,
            qty: line.qty,
            spokenUnitPrice: line.spokenAmount,
          ),
      ],
    ),
  );
}

/// The lines of a restock, in spoken order.
Result<RestockIntentInput> _restockInput(CommandProposal proposal) {
  return Success<RestockIntentInput>(
    RestockIntentInput(
      items: <RestockIntentLine>[
        for (final ItemMention line in _items(proposal))
          RestockIntentLine(
            productId: line.product.id,
            productName: line.product.name,
            qty: line.qty,
            spokenUnitCost: line.spokenAmount,
          ),
      ],
    ),
  );
}

/// The product asked about, or a named failure when the proposal carries none.
///
/// A read command with no product in it is not a call with an empty argument: it is
/// a question the module could not answer, and the handler is not called.
Result<QueryStockInput> _queryInput(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  if (productId == null) {
    return Failed<QueryStockInput>(
      UnknownProduct(productId: '', productName: null),
    );
  }
  return Success<QueryStockInput>(QueryStockInput(productId: productId));
}

List<ItemMention> _items(CommandProposal proposal) {
  return proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
      const <ItemMention>[];
}

Result<QueryDailyStatsInput> _dailyStatsInput(CommandProposal proposal) {
  return Success<QueryDailyStatsInput>(
    QueryDailyStatsInput(date: proposal.valueOf<String>('date')),
  );
}

Result<QueryLowStockInput> _lowStockInput(CommandProposal proposal) {
  return Success<QueryLowStockInput>(
    QueryLowStockInput(level: proposal.valueOf<String>('level')),
  );
}

Result<QueryProductPriceInput> _productPriceInput(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  if (productId == null || productId.isEmpty) {
    return Failed<QueryProductPriceInput>(
      UnknownProduct(productId: '', productName: null),
    );
  }
  return Success<QueryProductPriceInput>(
    QueryProductPriceInput(productId: productId),
  );
}

Result<RecordStockOutInput> _stockOutInput(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  if (productId == null || productId.isEmpty) {
    return Failed<RecordStockOutInput>(
      UnknownProduct(productId: '', productName: null),
    );
  }
  final double qty = proposal.valueOf<double>('qty') ?? 1.0;
  final String reason = proposal.valueOf<String>('reason') ?? 'breakage';
  final String? note = proposal.valueOf<String>('note');
  return Success<RecordStockOutInput>(
    RecordStockOutInput(
      productId: productId,
      qty: qty,
      reason: reason,
      note: note,
    ),
  );
}

Result<NavigateToPageInput> _navigateInput(CommandProposal proposal) {
  final String destination =
      proposal.valueOf<String>('destination') ?? 'dashboard';
  return Success<NavigateToPageInput>(
    NavigateToPageInput(destination: destination),
  );
}

Result<ExportSalesReportInput> _exportReportInput(CommandProposal proposal) {
  final String format = proposal.valueOf<String>('format') ?? 'pdf';
  final String? period = proposal.valueOf<String>('period');
  return Success<ExportSalesReportInput>(
    ExportSalesReportInput(format: format, period: period),
  );
}

Result<CreateProductInput> _createProductInput(CommandProposal proposal) {
  final String? name = proposal.valueOf<String>('name');
  if (name == null || name.isEmpty) {
    return Failed<CreateProductInput>(const EmptyItems('create_product'));
  }
  final double price = proposal.valueOf<double>('price') ?? 0.0;
  final double? purchasePrice = proposal.valueOf<double>('purchasePrice');
  final double? initialQty = proposal.valueOf<double>('initialQty');
  final String? category = proposal.valueOf<String>('category');
  final String? unit = proposal.valueOf<String>('unit');

  return Success<CreateProductInput>(
    CreateProductInput(
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      initialQty: initialQty,
      category: category,
      unit: unit,
    ),
  );
}

Result<UpdateProductPriceInput> _updatePriceInput(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  if (productId == null || productId.isEmpty) {
    return Failed<UpdateProductPriceInput>(
      UnknownProduct(productId: '', productName: null),
    );
  }
  final double newPrice = proposal.valueOf<double>('newPrice') ?? 0.0;
  return Success<UpdateProductPriceInput>(
    UpdateProductPriceInput(productId: productId, newPrice: newPrice),
  );
}

Result<QuerySalesHistoryInput> _salesHistoryInput(CommandProposal proposal) {
  final int? limit = proposal.valueOf<int>('limit');
  return Success<QuerySalesHistoryInput>(QuerySalesHistoryInput(limit: limit));
}

Result<QueryBusinessInfoInput> _businessInfoInput(CommandProposal proposal) {
  return const Success<QueryBusinessInfoInput>(QueryBusinessInfoInput());
}
