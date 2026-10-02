import '../entities/stock_movement.dart';
import '../repositories/stock_movement_repository.dart';

/// Erreur métier de mouvement de stock, à distinguer des pannes réseau.
///
/// [insufficientStock] est le cas courant côté vendeur : il ne doit pas être
/// affiché comme une erreur de connexion.
class StockMovementFailure implements Exception {
  const StockMovementFailure(this.reason, {this.available});

  const StockMovementFailure.insufficientStock({
    required int requested,
    required int available,
  }) : this(StockMovementFailureReason.insufficientStock, available: available);

  final StockMovementFailureReason reason;
  final int? available;

  String get message => switch (reason) {
    StockMovementFailureReason.insufficientStock =>
      "Stock insuffisant : ${available ?? 0} unité(s) disponible(s).",
    StockMovementFailureReason.invalidQuantity =>
      'La quantité doit être supérieure à zéro.',
    StockMovementFailureReason.productNotFound => "Ce produit n'existe plus.",
  };
}

enum StockMovementFailureReason {
  insufficientStock,
  invalidQuantity,
  productNotFound,
}

/// Enregistre une entrée de stock : UC7, achat ou réapprovisionnement.
class RecordStockIn {
  const RecordStockIn(this._repository);

  final StockMovementRepository _repository;

  Future<void> call(StockMovement movement) {
    _validate(movement);
    if (movement.type != StockMovementType.purchase) {
      throw ArgumentError.value(
        movement.type,
        'movement.type',
        'Une entrée de stock doit être de type purchase',
      );
    }
    return _repository.recordMovement(movement);
  }

  void _validate(StockMovement movement) {
    if (movement.productId.isEmpty) {
      throw ArgumentError.value(
        movement.productId,
        'movement.productId',
        'Un mouvement doit référencer un produit',
      );
    }
    if (movement.quantity <= 0) {
      throw const StockMovementFailure(
        StockMovementFailureReason.invalidQuantity,
      );
    }
  }
}

/// Enregistre une sortie manuelle : UC8, perte, casse ou don.
class RecordStockOut {
  const RecordStockOut(this._repository);

  final StockMovementRepository _repository;

  Future<void> call(StockMovement movement) {
    if (movement.productId.isEmpty) {
      throw ArgumentError.value(
        movement.productId,
        'movement.productId',
        'Un mouvement doit référencer un produit',
      );
    }
    if (movement.quantity <= 0) {
      throw const StockMovementFailure(
        StockMovementFailureReason.invalidQuantity,
      );
    }
    if (movement.type != StockMovementType.manualOut) {
      throw ArgumentError.value(
        movement.type,
        'movement.type',
        'Une sortie manuelle doit être de type manualOut',
      );
    }
    return _repository.recordMovement(movement);
  }
}
