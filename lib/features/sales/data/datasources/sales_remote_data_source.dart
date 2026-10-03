import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/exceptions/sales_exceptions.dart';
import '../models/sale_model.dart';

abstract class SalesRemoteDataSource {
  Future<SaleModel> recordSale(SaleModel sale);

  Future<SaleModel> cancelSale(String saleId);

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
  Future<SaleModel> recordSale(SaleModel sale) async {
    final batch = firestore.batch();

    final saleRef = sale.id != null && sale.id!.isNotEmpty
        ? salesCollection.doc(sale.id)
        : salesCollection.doc();

    final savedSale = SaleModel(
      id: saleRef.id,
      dateTime: sale.dateTime,
      createdAt: sale.createdAt,
      total: sale.total,
      items: sale.items,
      source: sale.source,
      status: sale.status,
      cancelledAt: sale.cancelledAt,
    );

    batch.set(saleRef, {
      ...savedSale.toMap(),
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

    return savedSale;
  }

  @override
  Future<SaleModel> cancelSale(String saleId) async {
    final saleDoc = await salesCollection.doc(saleId).get();

    if (!saleDoc.exists || saleDoc.data() == null) {
      throw SaleNotFoundException(saleId);
    }

    final sale = SaleModel.fromMap(saleDoc.data()!, id: saleDoc.id);

    if (sale.status == 'CANCELLED' || sale.cancelledAt != null) {
      throw AlreadyCancelledException(saleId);
    }

    final batch = firestore.batch();

    batch.update(saleDoc.reference, {
      'status': 'CANCELLED',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    for (final item in sale.items) {
      final productRef = firestore
          .collection('users')
          .doc(uid)
          .collection('products')
          .doc(item.productId);

      batch.update(productRef, {'stock': FieldValue.increment(item.qty)});
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
      'revenue': FieldValue.increment(-sale.total),
      'cost': FieldValue.increment(-cost),
      'salesCount': FieldValue.increment(-1),
    };

    for (final item in sale.items) {
      updates['qtyByProduct.${item.productId}'] = FieldValue.increment(
        -item.qty,
      );
    }

    batch.set(dailyStatsRef, updates, SetOptions(merge: true));

    await batch.commit();

    return SaleModel(
      id: sale.id,
      dateTime: sale.dateTime,
      createdAt: sale.createdAt,
      total: sale.total,
      items: sale.items,
      source: sale.source,
      status: 'CANCELLED',
      cancelledAt: DateTime.now(),
    );
  }

  @override
  Future<List<SaleModel>> getSalesHistory() async {
    final snapshot = await salesCollection
        .orderBy('dateTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SaleModel.fromMap(doc.data(), id: doc.id))
        .toList();
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

    return snapshot.docs
        .map((doc) => SaleModel.fromMap(doc.data(), id: doc.id))
        .toList();
  }
}
