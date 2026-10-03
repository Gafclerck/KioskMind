class Sale {
  final DateTime dateTime;
  final DateTime createdAt;
  final double total;
  final List<SaleItem> items;
  final String source;
  final String status;
  final DateTime? cancelledAt;

  Sale({
    required this.dateTime,
    required this.createdAt,
    required this.total,
    required this.items,
    required this.source,
    required this.status,
    this.cancelledAt,
  });
}

class SaleItem {
  final String productId;
  final String name;
  final double qty;
  final double unitPrice;
  final double? unitCost;

  SaleItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unitCost,
  });
}