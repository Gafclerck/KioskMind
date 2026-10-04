import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../sales/domain/entities/sale.dart';
import '../../../../sales/domain/exceptions/sales_exceptions.dart';
import '../../../../sales/domain/usecases/cancel_sale.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real implementation of the cancel last sale handler, calling the sales feature.
///
/// Follows the contract of `docs/voice/USE_CASE_CONTRACTS.md`:
/// - Restores the stock on the affected lines
/// - Never deletes the sale document
/// - Replays or unknown sale ids return typed Failures
final class RealCancelLastSaleHandler implements CancelLastSaleHandler {
  RealCancelLastSaleHandler({
    required this.cancelSale,
    required this.catalogReader,
  });

  final CancelSale cancelSale;
  final ProductCatalogReader catalogReader;

  @override
  String get intentId => kCancelLastSaleIntent;

  @override
  Future<Result<CancelLastSaleResult>> execute(
    CommandContext context,
    CancelLastSaleInput input,
  ) async {
    final String saleId = input.saleId;
    if (saleId.isEmpty) {
      return const Failed<CancelLastSaleResult>(SaleNotFound(''));
    }

    try {
      final Sale cancelledSale = await cancelSale(saleId);

      final List<SaleLineResult> restored = <SaleLineResult>[];
      for (final SaleItem item in cancelledSale.items) {
        final ProductSnapshot? product = await catalogReader.findById(
          item.productId,
        );
        restored.add((
          productId: item.productId,
          name: item.name,
          unit: product?.unit ?? 'PIECE',
          qty: item.qty,
          appliedUnitPrice: item.unitPrice,
          resultingStock: product?.stock ?? item.qty,
        ));
      }

      return Success<CancelLastSaleResult>((
        saleId: saleId,
        restored: restored,
      ));
    } on SaleNotFoundException catch (e) {
      return Failed<CancelLastSaleResult>(SaleNotFound(e.saleId));
    } on AlreadyCancelledException catch (e) {
      return Failed<CancelLastSaleResult>(AlreadyCancelled(e.saleId));
    } catch (_) {
      return Failed<CancelLastSaleResult>(SaleNotFound(saleId));
    }
  }
}
