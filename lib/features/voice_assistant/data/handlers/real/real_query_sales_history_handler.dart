import '../../../../../core/usecase/result.dart';
import '../../../../sales/domain/entities/sale.dart';
import '../../../../sales/domain/usecases/get_sales_history.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';

/// Real handler for querying recent sales history.
final class RealQuerySalesHistoryHandler implements QuerySalesHistoryHandler {
  RealQuerySalesHistoryHandler(this._getSalesHistory);

  final GetSalesHistory _getSalesHistory;

  @override
  String get intentId => 'query_sales_history';

  @override
  Future<Result<QuerySalesHistoryResult>> execute(
    CommandContext context,
    QuerySalesHistoryInput input,
  ) async {
    final int limit = input.limit ?? 5;
    final List<Sale> allSales = await _getSalesHistory();

    final List<Sale> recent = allSales.take(limit).toList();

    final List<SaleHistoryItemResult> items = <SaleHistoryItemResult>[
      for (final Sale sale in recent)
        (
          saleId: sale.id ?? '',
          dateTime: sale.dateTime,
          total: sale.total,
          itemsCount: sale.items.length,
        ),
    ];

    return Success<QuerySalesHistoryResult>((sales: items));
  }
}
