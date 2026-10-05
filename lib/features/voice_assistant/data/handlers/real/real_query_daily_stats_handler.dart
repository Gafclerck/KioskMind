import '../../../../../core/usecase/result.dart';
import '../../../../sales/domain/entities/daily_stats.dart';
import '../../../../sales/domain/usecases/get_sales_dashboard.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';

/// Real handler querying sales daily stats.
final class RealQueryDailyStatsHandler implements QueryDailyStatsHandler {
  RealQueryDailyStatsHandler(this._getSalesDashboard);

  final GetSalesDashboard _getSalesDashboard;

  @override
  String get intentId => 'query_daily_stats';

  @override
  Future<Result<QueryDailyStatsResult>> execute(
    CommandContext context,
    QueryDailyStatsInput input,
  ) async {
    final DateTime targetDate = _resolveDate(input.date, context.dateTime);
    final DateTime startOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final DateTime endOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      23,
      59,
      59,
    );

    try {
      final List<DailyStats> stats = await _getSalesDashboard(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      double totalRevenue = 0.0;
      double totalCost = 0.0;
      int salesCount = 0;
      int itemsSold = 0;

      for (final DailyStats stat in stats) {
        totalRevenue += stat.revenue;
        totalCost += stat.cost;
        salesCount += stat.salesCount;
        for (final double qty in stat.qtyByProduct.values) {
          itemsSold += qty.toInt();
        }
      }

      final double totalProfit = totalRevenue - totalCost;

      return Success<QueryDailyStatsResult>((
        date: startOfDay,
        salesCount: salesCount,
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        itemsSold: itemsSold,
      ));
    } catch (_) {
      return Success<QueryDailyStatsResult>((
        date: startOfDay,
        salesCount: 0,
        totalRevenue: 0.0,
        totalProfit: 0.0,
        itemsSold: 0,
      ));
    }
  }

  DateTime _resolveDate(String? dateStr, DateTime fallback) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'today') {
      return fallback;
    }
    if (dateStr == 'yesterday') {
      return fallback.subtract(const Duration(days: 1));
    }
    return DateTime.tryParse(dateStr) ?? fallback;
  }
}
