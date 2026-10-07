import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk_mind/core/firestore/offline_commit.dart';

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
  Future<void> recordMovement(StockMovement movement) async {
    final productRef = _products.doc(movement.productId);
    final movementRef = movement.id.isNotEmpty
        ? _movements.doc(movement.id)
        : _movements.doc();

    // Idempotence en cas de rejeu. Hors-ligne sans cache, l'id stable du
    // mouvement fait le même travail : le brouillon local ne sera appliqué
    // qu'une fois au moment du sync.
    if (movement.id.isNotEmpty) {
      try {
        final existingMovement = await movementRef.get();
        if (existingMovement.exists) {
          return;
        }
      } on Exception {
        // Lecture impossible (offline, cache froid) : on poursuit.
      }
    }

    // Le mouvement et la quantité du produit sont écrits ensemble dans un
    // batch. Une transaction serait plus stricte mais ne peut jamais être
    // servie hors-ligne : Firestore ne propose pas de transaction offline.
    // La file locale synchronisera le batch au retour du réseau.
    final batch = _firestore.batch();

    final DocumentSnapshot<Map<String, dynamic>>? productSnapshot =
        await _tryRead(productRef);
    if (productSnapshot != null) {
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

      batch.update(productRef, {'quantity': nextQuantity});
    } else {
      // Produit illisible (offline, cache froid) : la quantité exacte est
      // inconnue, on ne peut pas la garder. L'incrément appliquera le
      // mouvement de façon sûre au moment du sync ; la garde de stock
      // négatif n'est simplement pas vérifiable ici.
      batch.update(
        productRef,
        {'quantity': FieldValue.increment(movement.signedQuantity)},
      );
    }

    batch.set(movementRef, StockMovementModel.toFirestore(movement));
    await commitOffline(batch);
  }

  /// Reads [ref] or answers null when the read cannot succeed (offline, cache
  /// froid). A genuine "document has no data" is reported by [productSnapshot]
  /// as data() == null, so this never hides a missing product behind a null.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _tryRead(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } on Exception {
      return null;
    }
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