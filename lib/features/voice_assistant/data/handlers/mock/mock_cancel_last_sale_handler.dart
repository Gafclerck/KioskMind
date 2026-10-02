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

    final List<SaleLineResult> restored = _restoredLines(sale.lines);
    _catalog.applyCancellation(sale.saleId, context.dateTime, restored);
    return Success<CancelLastSaleResult>((
      saleId: sale.saleId,
      restored: restored,
    ));
  }

  /// Current stock has to be re-read: the sale document holds the quantities
  /// sold, not the stock left afterwards.
  List<SaleLineResult> _restoredLines(List<SaleLineResult> sold) {
    return <SaleLineResult>[
      for (final SaleLineResult line in sold)
        (
          productId: line.productId,
          name: line.name,
          unit: line.unit,
          qty: line.qty,
          appliedUnitPrice: line.appliedUnitPrice,
          // A sale only ever names products this catalog still holds: it
          // refuses unknown ones and archives instead of deleting them.
          resultingStock:
              _catalog.productById(line.productId)!.stock + line.qty,
        ),
    ];
  }
}
