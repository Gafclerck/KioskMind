import '../../domain/entities/stock_movement.dart';

abstract final class StockMovementModel {
  static StockMovement fromFirestore(String id, Map<String, dynamic> data) {
    return StockMovement(
      id: id,
      productId: data['productId'] as String,
      type: StockMovementType.values.byName(data['type'] as String),
      reason: StockMovementReason.values.byName(data['reason'] as String),
      quantity: (data['quantity'] as num).toInt(),
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      note: data['note'] as String?,
      authorId: data['authorId'] as String?,
    );
  }

  static Map<String, dynamic> toFirestore(StockMovement movement) => {
    'productId': movement.productId,
    'type': movement.type.name,
    'reason': movement.reason.name,
    'quantity': movement.quantity,
    'createdAt': movement.createdAt.toIso8601String(),
    'note': movement.note,
    'authorId': movement.authorId,
  };
}
