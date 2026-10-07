import '../../domain/entities/daily_stats.dart';
import '../../domain/repositories/daily_stats_repository.dart';
import '../datasources/daily_stats_remote_data_source.dart';

class DailyStatsRepositoryImpl implements DailyStatsRepository {
  final DailyStatsRemoteDataSource remoteDataSource;

  DailyStatsRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<DailyStats>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await remoteDataSource.getDailyStats(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
