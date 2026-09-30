class Product {
  const Product({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.category,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.alertThreshold,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String category;
  final String unit;
  final int purchasePrice;
  final int salePrice;
  final int quantity;
  final int alertThreshold;
  int get margin => salePrice - purchasePrice;

  Product copyWith({
    String? name,
    String? imageUrl,
    String? category,
    String? unit,
    int? purchasePrice,
    int? salePrice,
    int? quantity,
    int? alertThreshold,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      alertThreshold: alertThreshold ?? this.alertThreshold,
    );
  }
}
