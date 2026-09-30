import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../catalog/in_memory_product_catalog.dart';

/// Mock of the sale cancellation, backed by the in-memory store.
///
/// The sale is never deleted: its status changes and the stock is given back,
/// which is what the Firestore rules and the data model both require.
final class MockCancelLastSaleHandler implements CancelLastSaleHandler {
  MockCancelLastSaleHandler(this._catalog);

  final InMemoryProductCatalog _catalog;

  @override
  String get intentId => 'cancel_last_sale';

  @override
  Future<Result<CancelLastSaleResult>> execute(
    CommandContext context,
    CancelLastSaleInput input,
  ) async {
    final StoredSale? sale = _catalog.saleById(input.saleId);
    if (sale == null) {
      return Failed<CancelLastSaleResult>(SaleNotFound(input.saleId));
    }
    if (sale.cancelledAt != null) {
      return Failed<CancelLastSaleResult>(AlreadyCancelled(input.saleId));
    }

    final List<SaleLineResult> restored = <SaleLineResult>[
      for (final SaleLineResult line in sale.lines)
        (
          productId: line.productId,
          name: line.name,
          unit: line.unit,
          qty: line.qty,
          appliedUnitPrice: line.appliedUnitPrice,
          resultingStock: _catalog.stockAfter(line.productId, line.qty)!,
        ),
    ];
    _catalog.applyCancellation(sale.saleId, context.dateTime, restored);
    return Success<CancelLastSaleResult>((
      saleId: sale.saleId,
      restored: restored,
    ));
  }
}
