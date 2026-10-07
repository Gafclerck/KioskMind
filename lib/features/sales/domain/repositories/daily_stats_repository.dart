import '../entities/daily_stats.dart';

abstract class DailyStatsRepository {
  Future<List<DailyStats>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  });
}
