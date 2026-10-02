import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_movement_repository.dart';
import '../../domain/usecases/record_stock_movement.dart';
import '../models/stock_movement_model.dart';

class StockMovementRepositoryImpl implements StockMovementRepository {
  StockMovementRepositoryImpl({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _products = firestore
           .collection('users')
           .doc(userId)
           .collection('products'),
       _movements = firestore
           .collection('users')
           .doc(userId)
           .collection('stockMovements');

  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _products;
  final CollectionReference<Map<String, dynamic>> _movements;

  @override
  Future<void> recordMovement(StockMovement movement) {
    final productRef = _products.doc(movement.productId);
    final movementRef = _movements.doc();

    // Transaction Firestore : le mouvement et la quantité du produit sont
    // écrits ensemble. Sans cela un incident entre les deux écritures laisse
    // le stock incohérent avec l'historique.
    return _firestore.runTransaction<void>((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      final data = productSnapshot.data();
      if (data == null) {
        throw const StockMovementFailure(
          StockMovementFailureReason.productNotFound,
        );
      }

      final currentQuantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final nextQuantity = currentQuantity + movement.signedQuantity;

      if (nextQuantity < 0) {
        throw StockMovementFailure.insufficientStock(
          requested: movement.quantity,
          available: currentQuantity,
        );
      }

      transaction.update(productRef, {'quantity': nextQuantity});
      transaction.set(movementRef, StockMovementModel.toFirestore(movement));
    });
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) {
    return _movements
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => StockMovementModel.fromFirestore(doc.id, doc.data()),
              )
              .toList(),
        );
  }
}
