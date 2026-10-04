import '../../domain/entities/daily_stats.dart';

class DailyStatsModel extends DailyStats {
  DailyStatsModel({
    required super.revenue,
    required super.cost,
    required super.salesCount,
    required super.qtyByProduct,
  });

  factory DailyStatsModel.fromMap(Map<String, dynamic> map) {
    return DailyStatsModel(
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      salesCount: (map['salesCount'] as num?)?.toInt() ?? 0,
      qtyByProduct: Map<String, dynamic>.from(
        map['qtyByProduct'] as Map? ?? {},
      ).map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }
}
