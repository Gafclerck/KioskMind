import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/daily_stats_remote_data_source.dart';
import '../../data/datasources/sales_remote_data_source.dart';
import '../../data/repositories/daily_stats_repository_impl.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/daily_stats_repository.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/usecases/cancel_sale.dart';
import '../../domain/usecases/get_sales_dashboard.dart';
import '../../domain/usecases/get_sales_history.dart';
import '../../domain/usecases/record_sale.dart';
import '../../domain/usecases/update_sale.dart';

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>((ref) {
  return SalesRemoteDataSourceImpl(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepositoryImpl(ref.watch(salesRemoteDataSourceProvider));
});

final getSalesHistoryProvider = Provider<GetSalesHistory>((ref) {
  return GetSalesHistory(ref.watch(salesRepositoryProvider));
});

final recordSaleProvider = Provider<RecordSale>((ref) {
  return RecordSale(ref.watch(salesRepositoryProvider));
});

final updateSaleProvider = Provider<UpdateSale>((ref) {
  return UpdateSale(ref.watch(salesRepositoryProvider));
});

final cancelSaleProvider = Provider<CancelSale>((ref) {
  return CancelSale(ref.watch(salesRepositoryProvider));
});

final dailyStatsRemoteDataSourceProvider = Provider<DailyStatsRemoteDataSource>(
  (ref) {
    return DailyStatsRemoteDataSourceImpl(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );
  },
);

final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>((ref) {
  return DailyStatsRepositoryImpl(
    ref.watch(dailyStatsRemoteDataSourceProvider),
  );
});

final getSalesDashboardProvider = Provider<GetSalesDashboard>((ref) {
  return GetSalesDashboard(ref.watch(dailyStatsRepositoryProvider));
});
