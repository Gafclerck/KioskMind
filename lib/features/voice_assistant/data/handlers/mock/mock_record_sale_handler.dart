import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../canonical_arguments.dart';
import '../../catalog/in_memory_product_catalog.dart';

/// Mock of the sale use case, backed by the in-memory store.
///
/// Follows the contract of `docs/voice/USE_CASE_CONTRACTS.md`: the catalog
/// price is applied, the spoken price only raises a doubt upstream, the stock
/// may go negative, and a replayed command identifier returns the first result
/// instead of writing twice.
final class MockRecordSaleHandler implements RecordSaleHandler {
  MockRecordSaleHandler(this._catalog);

  final InMemoryProductCatalog _catalog;

  @override
  String get intentId => 'record_sale';

  @override
  Future<Result<RecordSaleResult>> execute(
    CommandContext context,
    SaleIntentInput input,
  ) async {
    if (input.items.isEmpty) {
      return Failed<RecordSaleResult>(const EmptyItems('record_sale'));
    }

    final RecordSaleResult? replayed = _catalog.saleResultByCommandId(
      context.commandId,
    );
    if (replayed != null) {
      return Success<RecordSaleResult>(replayed);
    }

    final List<SaleLineResult> lines = <SaleLineResult>[];
    for (final SaleIntentLine item in input.items) {
      switch (_line(item)) {
        case Failed<SaleLineResult>(:final Failure failure):
          return Failed<RecordSaleResult>(failure);
        case Success<SaleLineResult>(:final SaleLineResult value):
          lines.add(value);
      }
    }

    final RecordSaleResult result = (
      saleId: context.commandId,
      total: roundAmount(
        lines.fold<double>(
          0,
          (double sum, SaleLineResult line) =>
              sum + line.qty * line.appliedUnitPrice,
        ),
      ),
      lines: lines,
    );
    _catalog.applySale(context, result);
    return Success<RecordSaleResult>(result);
  }

  Result<SaleLineResult> _line(SaleIntentLine item) {
    final ProductSnapshot? product = _catalog.productById(item.productId);
    if (product == null) {
      return Failed<SaleLineResult>(UnknownProduct(productId: item.productId));
    }
    if (product.isArchived) {
      return Failed<SaleLineResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }
    if (item.qty <= 0) {
      return Failed<SaleLineResult>(
        InvalidQuantity(productId: product.id, qty: item.qty),
      );
    }
    return Success<SaleLineResult>((
      productId: product.id,
      name: product.name,
      unit: product.unit,
      qty: item.qty,
      appliedUnitPrice: product.price,
      resultingStock: _catalog.stockAfter(product.id, -item.qty)!,
    ));
  }
}
