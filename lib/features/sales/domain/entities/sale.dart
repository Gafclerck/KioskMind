enum SaleStatus {
  active,
  cancelled,
}

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

class Sale {
  final String id;
  final String shopId;
  final DateTime date;
  final List<SaleItem> items;
  final double totalAmount;
  final SaleStatus status;

  const Sale({
    required this.id,
    required this.shopId,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.status,
  });
}