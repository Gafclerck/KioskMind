import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/sale.dart';
import '../../domain/exceptions/sales_exceptions.dart';
import '../models/sale_model.dart';

abstract class SalesRemoteDataSource {
  Future<SaleModel> recordSale(SaleModel sale);

  Future<SaleModel> updateSale(SaleModel sale);

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

  CollectionReference<Map<String, dynamic>> get productsCollection =>
      firestore.collection('users').doc(uid).collection('products');

  CollectionReference<Map<String, dynamic>> get dailyStatsCollection =>
      firestore.collection('users').doc(uid).collection('dailyStats');

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

    final stockChanges = <String, double>{};

    for (final item in sale.items) {
      stockChanges[item.productId] =
          (stockChanges[item.productId] ?? 0) - item.qty;
    }

    for (final entry in stockChanges.entries) {
      final productRef = productsCollection.doc(entry.key);

      batch.update(productRef, {
        'quantity': FieldValue.increment(entry.value.toInt()),
      });
    }

    final dateId = _dateId(sale.dateTime);
    final dailyStatsRef = dailyStatsCollection.doc(dateId);

    final cost = _calculateCost(sale.items);

    final statsUpdates = <String, dynamic>{
      'revenue': FieldValue.increment(sale.total),
      'cost': FieldValue.increment(cost),
      'salesCount': FieldValue.increment(1),
    };

    final quantitiesByProduct = _groupQuantitiesByProduct(sale.items);

    for (final entry in quantitiesByProduct.entries) {
      statsUpdates['qtyByProduct.${entry.key}'] = FieldValue.increment(
        entry.value,
      );
    }

    batch.set(dailyStatsRef, statsUpdates, SetOptions(merge: true));

    await batch.commit();

    return savedSale;
  }

  @override
  Future<SaleModel> updateSale(SaleModel sale) async {
    if (sale.id == null || sale.id!.isEmpty) {
      throw Exception('Impossible de modifier une vente sans identifiant');
    }

    final saleRef = salesCollection.doc(sale.id);

    final saleDoc = await saleRef.get();

    if (!saleDoc.exists || saleDoc.data() == null) {
      throw SaleNotFoundException(sale.id!);
    }

    final oldSale = SaleModel.fromMap(saleDoc.data()!, id: saleDoc.id);

    if (oldSale.status == 'CANCELLED' || oldSale.cancelledAt != null) {
      throw AlreadyCancelledException(sale.id!);
    }

    final batch = firestore.batch();

    final stockChanges = <String, double>{};

    for (final item in oldSale.items) {
      stockChanges[item.productId] =
          (stockChanges[item.productId] ?? 0) + item.qty;
    }

    for (final item in sale.items) {
      stockChanges[item.productId] =
          (stockChanges[item.productId] ?? 0) - item.qty;
    }

    for (final entry in stockChanges.entries) {
      if (entry.value == 0) {
        continue;
      }

      final productRef = productsCollection.doc(entry.key);

      batch.update(productRef, {
        'quantity': FieldValue.increment(entry.value.toInt()),
      });
    }

    final oldDateId = _dateId(oldSale.dateTime);
    final newDateId = _dateId(sale.dateTime);

    final oldCost = _calculateCost(oldSale.items);
    final newCost = _calculateCost(sale.items);

    final oldQuantities = _groupQuantitiesByProduct(oldSale.items);

    final newQuantities = _groupQuantitiesByProduct(sale.items);

    if (oldDateId == newDateId) {
      final dailyStatsRef = dailyStatsCollection.doc(oldDateId);

      final statsUpdates = <String, dynamic>{
        'revenue': FieldValue.increment(sale.total - oldSale.total),
        'cost': FieldValue.increment(newCost - oldCost),
      };

      final productIds = <String>{...oldQuantities.keys, ...newQuantities.keys};

      for (final productId in productIds) {
        final oldQty = oldQuantities[productId] ?? 0;
        final newQty = newQuantities[productId] ?? 0;

        final delta = newQty - oldQty;

        if (delta != 0) {
          statsUpdates['qtyByProduct.$productId'] = FieldValue.increment(delta);
        }
      }

      batch.set(dailyStatsRef, statsUpdates, SetOptions(merge: true));
    } else {
      final oldDailyStatsRef = dailyStatsCollection.doc(oldDateId);

      final oldStatsUpdates = <String, dynamic>{
        'revenue': FieldValue.increment(-oldSale.total),
        'cost': FieldValue.increment(-oldCost),
        'salesCount': FieldValue.increment(-1),
      };

      for (final entry in oldQuantities.entries) {
        oldStatsUpdates['qtyByProduct.${entry.key}'] = FieldValue.increment(
          -entry.value,
        );
      }

      batch.set(oldDailyStatsRef, oldStatsUpdates, SetOptions(merge: true));

      final newDailyStatsRef = dailyStatsCollection.doc(newDateId);

      final newStatsUpdates = <String, dynamic>{
        'revenue': FieldValue.increment(sale.total),
        'cost': FieldValue.increment(newCost),
        'salesCount': FieldValue.increment(1),
      };

      for (final entry in newQuantities.entries) {
        newStatsUpdates['qtyByProduct.${entry.key}'] = FieldValue.increment(
          entry.value,
        );
      }

      batch.set(newDailyStatsRef, newStatsUpdates, SetOptions(merge: true));
    }

    final updatedSale = SaleModel(
      id: sale.id,
      dateTime: sale.dateTime,

      createdAt: oldSale.createdAt,

      total: sale.total,
      items: sale.items,

      source: oldSale.source,

      status: sale.status,

      cancelledAt: null,
    );

    batch.update(saleRef, updatedSale.toMap());

    await batch.commit();

    return updatedSale;
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

    final stockChanges = <String, double>{};

    for (final item in sale.items) {
      stockChanges[item.productId] =
          (stockChanges[item.productId] ?? 0) + item.qty;
    }

    for (final entry in stockChanges.entries) {
      final productRef = productsCollection.doc(entry.key);

      batch.update(productRef, {
        'quantity': FieldValue.increment(entry.value.toInt()),
      });
    }

    final dateId = _dateId(sale.dateTime);

    final dailyStatsRef = dailyStatsCollection.doc(dateId);

    final cost = _calculateCost(sale.items);

    final statsUpdates = <String, dynamic>{
      'revenue': FieldValue.increment(-sale.total),
      'cost': FieldValue.increment(-cost),
      'salesCount': FieldValue.increment(-1),
    };

    final quantitiesByProduct = _groupQuantitiesByProduct(sale.items);

    for (final entry in quantitiesByProduct.entries) {
      statsUpdates['qtyByProduct.${entry.key}'] = FieldValue.increment(
        -entry.value,
      );
    }

    batch.set(dailyStatsRef, statsUpdates, SetOptions(merge: true));

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

  String _dateId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double _calculateCost(List<SaleItem> items) {
    return items.fold<double>(0, (total, item) {
      return total + ((item.unitCost ?? 0) * item.qty);
    });
  }

  Map<String, double> _groupQuantitiesByProduct(List<SaleItem> items) {
    final quantities = <String, double>{};

    for (final item in items) {
      quantities[item.productId] = (quantities[item.productId] ?? 0) + item.qty;
    }

    return quantities;
  }
}
