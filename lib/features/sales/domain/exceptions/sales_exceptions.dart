class SaleNotFoundException implements Exception {
  final String saleId;
  const SaleNotFoundException(this.saleId);

  @override
  String toString() => 'SaleNotFoundException(saleId: $saleId)';
}

class AlreadyCancelledException implements Exception {
  final String saleId;
  const AlreadyCancelledException(this.saleId);

  @override
  String toString() => 'AlreadyCancelledException(saleId: $saleId)';
}
