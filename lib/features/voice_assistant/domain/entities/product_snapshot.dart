/// Read model of a product, as the voice module sees it.
///
/// Built by [ProductCatalogReader] from the product collection. Only the fields
/// the voice needs to route a command are exposed; nothing here is a Firestore
/// document, so the real catalog reader stays a swappable adapter.
final class ProductSnapshot {
  const ProductSnapshot({
    required this.id,
    required this.name,
    required this.aliases,
    required this.unit,
    required this.price,
    required this.purchasePrice,
    required this.stock,
    required this.alertThreshold,
    required this.averageDailyQty,
    this.isArchived = false,
  });

  final String id;
  final String name;

  /// Spoken synonyms, already normalized. An empty list is legitimate.
  final List<String> aliases;

  /// Unit code: `PIECE`, `KG`, `LITRE`, `SACHET`.
  final String unit;

  /// Selling price, applied unless a doubt is raised (see contract A7).
  final double price;

  /// Current purchase cost, used for margin. Null when unknown.
  final double? purchasePrice;

  /// Estimated stock. Can be negative: the voice never blocks a sale.
  final double stock;

  final double alertThreshold;

  /// Habitual daily quantity, used to spot an unusual quantity (contract A11).
  final double averageDailyQty;

  final bool isArchived;

  ProductSnapshot withStock(double value) {
    return ProductSnapshot(
      id: id,
      name: name,
      aliases: aliases,
      unit: unit,
      price: price,
      purchasePrice: purchasePrice,
      stock: value,
      alertThreshold: alertThreshold,
      averageDailyQty: averageDailyQty,
      isArchived: isArchived,
    );
  }

  /// Persistence form, used by the offline catalog snapshot stores.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'aliases': aliases,
        'unit': unit,
        'price': price,
        'purchasePrice': purchasePrice,
        'stock': stock,
        'alertThreshold': alertThreshold,
        'averageDailyQty': averageDailyQty,
        'isArchived': isArchived,
      };

  /// Restores a snapshot persisted by [toJson]. Only called on trusted local
  /// data, so field casts are safe and a missing optional stays null.
  factory ProductSnapshot.fromJson(Map<String, dynamic> json) {
    return ProductSnapshot(
      id: json['id'] as String,
      name: json['name'] as String,
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[]).cast<String>(),
      unit: json['unit'] as String,
      price: (json['price'] as num).toDouble(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      stock: (json['stock'] as num).toDouble(),
      alertThreshold: (json['alertThreshold'] as num).toDouble(),
      averageDailyQty: (json['averageDailyQty'] as num).toDouble(),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}
