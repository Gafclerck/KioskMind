import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sale_model.dart';

abstract class SalesRemoteDataSource {
  Future<void> recordSale(SaleModel sale);

  Future<List<SaleModel>> getSalesHistory();

  Future<List<SaleModel>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });
}

class SalesRemoteDataSourceImpl implements SalesRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  SalesRemoteDataSourceImpl({required this.firestore, required this.auth});

  String get uid {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get salesCollection =>
      firestore.collection('users').doc(uid).collection('sales');

  @override
  Future<void> recordSale(SaleModel sale) async {
    final batch = firestore.batch();

    final saleRef = salesCollection.doc();

    batch.set(saleRef, {
      ...sale.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final item in sale.items) {
      final productRef = firestore
          .collection('users')
          .doc(uid)
          .collection('products')
          .doc(item.productId);

      batch.update(productRef, {'stock': FieldValue.increment(-item.qty)});
    }

    final dateId =
        '${sale.dateTime.year.toString().padLeft(4, '0')}'
        '${sale.dateTime.month.toString().padLeft(2, '0')}'
        '${sale.dateTime.day.toString().padLeft(2, '0')}';

    final dailyStatsRef = firestore
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .doc(dateId);

    final cost = sale.items.fold<double>(
      0,
      (total, item) => total + ((item.unitCost ?? 0) * item.qty),
    );

    final updates = <String, dynamic>{
      'revenue': FieldValue.increment(sale.total),
      'cost': FieldValue.increment(cost),
      'salesCount': FieldValue.increment(1),
    };

    for (final item in sale.items) {
      updates['qtyByProduct.${item.productId}'] = FieldValue.increment(
        item.qty,
      );
    }

    batch.set(dailyStatsRef, updates, SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Future<List<SaleModel>> getSalesHistory() async {
    // À implémenter ensuite
    return [];
  }

  @override
  Future<List<SaleModel>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await salesCollection
        .where(
          'dateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('dateTime', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('dateTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => SaleModel.fromMap(doc.data())).toList();
  }
}
