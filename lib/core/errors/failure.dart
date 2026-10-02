/// Base type of every typed failure.
///
/// A failure carries a stable code and typed fields, never a displayable string:
/// user-facing text is produced later from [code], in the language the merchant
/// selected. The fields are the machine context, so no parallel map is needed.
/// See decision D12.
sealed class Failure {
  const Failure(this.code);

  /// Stable identifier, uppercase and underscore separated.
  final String code;
}

final class UnknownProduct extends Failure {
  const UnknownProduct({required this.productId, this.productName})
    : super('UNKNOWN_PRODUCT');

  final String productId;
  final String? productName;
}

final class ArchivedProduct extends Failure {
  const ArchivedProduct({required this.productId, this.productName})
    : super('ARCHIVED_PRODUCT');

  final String productId;
  final String? productName;
}

final class InvalidQuantity extends Failure {
  const InvalidQuantity({required this.productId, required this.qty})
    : super('INVALID_QUANTITY');

  final String productId;
  final double qty;
}

final class EmptyItems extends Failure {
  const EmptyItems(this.intentId) : super('EMPTY_ITEMS');

  final String intentId;
}

final class SaleNotFound extends Failure {
  const SaleNotFound(this.saleId) : super('SALE_NOT_FOUND');

  final String saleId;
}

final class AlreadyCancelled extends Failure {
  const AlreadyCancelled(this.saleId) : super('ALREADY_CANCELLED');

  final String saleId;
}

/// The merchant asked to undo, and the session holds no sale to undo.
///
/// Its own failure rather than a refusal from the policy: the words were
/// understood, there was simply nothing left to cancel. The presentation can say
/// so and offer the history, which is what the merchant expects, instead of
/// repeating "I did not understand".
final class NothingToUndo extends Failure {
  const NothingToUndo() : super('NOTHING_TO_UNDO');
}
