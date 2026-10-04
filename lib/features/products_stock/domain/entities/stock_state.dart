import '../entities/stock_movement.dart';

/// Vue agrégée de l'état du stock d'un produit, pour UC9.
class StockState {
  const StockState({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.alertThreshold,
    required this.level,
    required this.lastMovementAt,
  });

  final String productId;
  final String productName;
  final int quantity;
  final int alertThreshold;
  final StockAlertLevel level;
  final DateTime? lastMovementAt;

  int get missingUnits =>
      level.needsAttention ? (alertThreshold - quantity).clamp(0, 1 << 31) : 0;

  bool get isCritical => level == StockAlertLevel.critical;
}

/// Agrégat global du stock du kiosk.
class StockOverview {
  const StockOverview({
    required this.totalProducts,
    required this.totalUnits,
    required this.outOfStock,
    required this.rupture,
    required this.critical,
    required this.stockValue,
  });

  static const empty = StockOverview(
    totalProducts: 0,
    totalUnits: 0,
    outOfStock: 0,
    rupture: 0,
    critical: 0,
    stockValue: 0,
  );

  final int totalProducts;
  final int totalUnits;
  final int outOfStock;
  final int rupture;
  final int critical;

  /// Valeur du stock au prix d'achat, en FCFA.
  final int stockValue;

  /// Nombre de produits demandant une action, tous niveaux confondus.
  int get needsAttention => outOfStock + rupture + critical;

  bool get hasAlerts => needsAttention > 0;
}
