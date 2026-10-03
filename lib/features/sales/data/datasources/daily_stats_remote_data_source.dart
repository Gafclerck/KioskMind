import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/daily_stats_model.dart';

abstract class DailyStatsRemoteDataSource {
  Future<List<DailyStatsModel>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  });
}

class DailyStatsRemoteDataSourceImpl implements DailyStatsRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  DailyStatsRemoteDataSourceImpl({required this.firestore, required this.auth});

  String get uid {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get dailyStatsCollection =>
      firestore.collection('users').doc(uid).collection('dailyStats');

  @override
  Future<List<DailyStatsModel>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startId =
        '${startDate.year.toString().padLeft(4, '0')}'
        '${startDate.month.toString().padLeft(2, '0')}'
        '${startDate.day.toString().padLeft(2, '0')}';

    final endId =
        '${endDate.year.toString().padLeft(4, '0')}'
        '${endDate.month.toString().padLeft(2, '0')}'
        '${endDate.day.toString().padLeft(2, '0')}';

    final snapshot = await dailyStatsCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .get();

    return snapshot.docs
        .map((doc) => DailyStatsModel.fromMap(doc.data()))
        .toList();
  }
}
