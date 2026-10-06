enum AlertType { lowStock, negativeStock, predictedStockout }

enum AlertStatus { active, resolved }

class Alert {
  final String id;
  final AlertType type;
  final String productId;
  final String productName;
  final int stockAtCreation;
  final int? estimatedDaysLeft; // seulement pour predictedStockout
  final AlertStatus status;
  final DateTime createdAt;

  const Alert({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.stockAtCreation,
    this.estimatedDaysLeft,
    required this.status,
    required this.createdAt,
  });
}
