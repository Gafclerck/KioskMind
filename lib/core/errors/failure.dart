/// Base type of every typed failure.
///
/// A failure carries a stable code and machine context, never a displayable
/// string: user-facing text is produced later from [code], in the language the
/// merchant selected. See decision D12.
sealed class Failure {
  const Failure(this.code);

  /// Stable identifier, uppercase and underscore separated.
  final String code;

  /// Details for logs and assertions. Subclasses derive it from their fields.
  Map<String, Object?> get context => const <String, Object?>{};
}

final class UnknownProduct extends Failure {
  const UnknownProduct({required this.productId, this.productName})
    : super('UNKNOWN_PRODUCT');

  final String productId;
  final String? productName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'productId': productId,
    if (productName != null) 'productName': productName,
  };
}

final class ArchivedProduct extends Failure {
  const ArchivedProduct({required this.productId, this.productName})
    : super('ARCHIVED_PRODUCT');

  final String productId;
  final String? productName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'productId': productId,
    if (productName != null) 'productName': productName,
  };
}

final class InvalidQuantity extends Failure {
  const InvalidQuantity({required this.productId, required this.qty})
    : super('INVALID_QUANTITY');

  final String productId;
  final double qty;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'productId': productId,
    'qty': qty,
  };
}

final class EmptyItems extends Failure {
  const EmptyItems(this.intentId) : super('EMPTY_ITEMS');

  final String intentId;

  @override
  Map<String, Object?> get context => <String, Object?>{'intentId': intentId};
}

final class SaleNotFound extends Failure {
  const SaleNotFound(this.saleId) : super('SALE_NOT_FOUND');

  final String saleId;
}

final class AlreadyCancelled extends Failure {
  const AlreadyCancelled(this.saleId) : super('ALREADY_CANCELLED');

  final String saleId;
}
