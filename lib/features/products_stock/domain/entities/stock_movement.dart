enum StockMovementType {
  /// Réception d'un achat ou d'un réapprovisionnement fournisseur.
  purchase,

  /// Vente enregistrée.
  sale,

  /// Sortie manuelle : perte, casse, don.
  manualOut;

  /// Les entrées ne font qu'augmenter le stock.
  bool get isInbound => this == StockMovementType.purchase;
}

enum StockMovementReason {
  purchase,
  sale,
  loss,
  breakage,
  donation,
  manualAdjustment,
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.reason,
    required this.quantity,
    required this.createdAt,
    this.note,
    this.authorId,
  });

  final String id;
  final String productId;
  final StockMovementType type;

  /// Motif fin du mouvement, plus précis que [type] pour les sorties manuelles.
  final StockMovementReason reason;

  /// Toujours positif : c'est [type] qui détermine le signe appliqué au stock.
  final int quantity;
  final DateTime createdAt;
  final String? note;
  final String? authorId;

  /// Quantité signée à appliquer au stock du produit.
  int get signedQuantity => type.isInbound ? quantity : -quantity;

  /// Effet sur le niveau de stock, utilisé pour l'historique et les alertes.
  String get impactLabel => type.isInbound ? '+$quantity' : '-$quantity';
}

enum StockAlertLevel {
  outOfStock('Rupture de Stock'),
  rupture('Alerte Rupture'),
  critical('Niveau critique'),
  ok('Stock OK');

  const StockAlertLevel(this.label);

  final String label;

  /// Un niveau au-dessus de [ok] demande une action du vendeur.
  bool get needsAttention => this != StockAlertLevel.ok;
}

/// Détermine le niveau d'alerte d'un produit à partir de sa quantité et de son seuil.
///
/// Atteindre le seuil n'est pas encore une rupture : [StockAlertLevel.rupture]
/// couvre l'égalité, [StockAlertLevel.critical] le passage en dessous.
StockAlertLevel stockAlertLevelFor({
  required int quantity,
  required int alertThreshold,
}) {
  if (quantity <= 0) return StockAlertLevel.outOfStock;
  if (quantity < alertThreshold) return StockAlertLevel.critical;
  if (quantity <= alertThreshold) return StockAlertLevel.rupture;
  return StockAlertLevel.ok;
}
