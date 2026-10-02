import '../entities/stock_movement.dart';
import '../usecases/record_stock_movement.dart';

abstract interface class StockMovementRepository {
  /// Écrit le mouvement et met à jour la quantité du produit en une seule
  /// opération, afin qu'un incident réseau ne laisse pas les deux désalignés.
  ///
  /// Lève [StockMovementFailure] si la quantité demandée n'est pas disponible.
  Future<void> recordMovement(StockMovement movement);

  Stream<List<StockMovement>> watchMovements(String productId);
}
