import '../entities/daily_stats.dart';
import '../repositories/daily_stats_repository.dart';

class GetSalesDashboard {
  final DailyStatsRepository repository;

  GetSalesDashboard(this.repository);

  Future<List<DailyStats>> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await repository.getDailyStats(
      startDate: startDate,
      endDate: endDate,
    );
  }
}