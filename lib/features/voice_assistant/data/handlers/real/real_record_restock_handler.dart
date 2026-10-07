import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../products_stock/domain/entities/stock_movement.dart';
import '../../../../products_stock/domain/usecases/record_stock_movement.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';

/// Real implementation of the restock handler, delegating to [RecordStockIn].
///
/// Idempotent across retries using the voice command ID.
final class RealRecordRestockHandler implements RecordRestockHandler {
  RealRecordRestockHandler({
    required this.recordStockIn,
    required this.catalogReader,
  });

  final RecordStockIn recordStockIn;
  final ProductCatalogReader catalogReader;
  final Map<String, RecordRestockResult> _recordedCommands =
      <String, RecordRestockResult>{};

  @override
  String get intentId => 'record_restock';

  @override
  Future<Result<RecordRestockResult>> execute(
    CommandContext context,
    RestockIntentInput input,
  ) async {
    if (input.items.isEmpty) {
      return Failed<RecordRestockResult>(const EmptyItems('record_restock'));
    }

    final RecordRestockResult? replayed = _recordedCommands[context.commandId];
    if (replayed != null) {
      return Success<RecordRestockResult>(replayed);
    }

    final List<RestockLineResult> lines = <RestockLineResult>[];
    for (final RestockIntentLine item in input.items) {
      final Result<RestockLineResult> lineResult = await _line(item);
      switch (lineResult) {
        case Failed<RestockLineResult>(:final Failure failure):
          return Failed<RecordRestockResult>(failure);
        case Success<RestockLineResult>(:final RestockLineResult value):
          lines.add(value);
      }
    }

    try {
      final List<String> movementIds = <String>[];
      for (int index = 0; index < lines.length; index++) {
        final RestockIntentLine item = input.items[index];
        final String movementId = '${context.commandId}-$index';
        movementIds.add(movementId);

        final int movementQty =
            item.qty < 1 ? item.qty.ceil() : item.qty.round();

        final StockMovement movement = StockMovement(
          id: movementId,
          productId: item.productId,
          type: StockMovementType.purchase,
          reason: StockMovementReason.purchase,
          quantity: movementQty,
          createdAt: context.dateTime,
          note: 'Commande vocale ${context.commandId}',
        );
        await recordStockIn(movement);
      }

      final RecordRestockResult result = (
        movementIds: movementIds,
        lines: lines,
      );
      _recordedCommands[context.commandId] = result;
      return Success<RecordRestockResult>(result);
    } on Exception catch (_) {
      return Failed<RecordRestockResult>(
        UnknownProduct(productId: input.items.first.productId),
      );
    }
  }

  Future<Result<RestockLineResult>> _line(RestockIntentLine item) async {
    final ProductSnapshot? product = await catalogReader.findById(
      item.productId,
    );
    if (product == null) {
      return Failed<RestockLineResult>(
        UnknownProduct(productId: item.productId),
      );
    }
    if (product.isArchived) {
      return Failed<RestockLineResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }
    if (item.qty <= 0) {
      return Failed<RestockLineResult>(
        InvalidQuantity(productId: product.id, qty: item.qty),
      );
    }
    return Success<RestockLineResult>((
      productId: product.id,
      name: product.name,
      qty: item.qty,
      appliedUnitCost: item.spokenUnitCost,
      resultingStock: product.stock + item.qty,
    ));
  }
}
