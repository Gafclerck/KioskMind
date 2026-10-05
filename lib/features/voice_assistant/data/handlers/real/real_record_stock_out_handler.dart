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

/// Real handler for recording manual stock reductions (loss, breakage, donation, adjustment).
final class RealRecordStockOutHandler implements RecordStockOutHandler {
  RealRecordStockOutHandler({
    required this.recordStockOut,
    required this.catalogReader,
  });

  final RecordStockOut recordStockOut;
  final ProductCatalogReader catalogReader;
  final Map<String, RecordStockOutResult> _recordedCommands =
      <String, RecordStockOutResult>{};

  @override
  String get intentId => 'record_stock_out';

  @override
  Future<Result<RecordStockOutResult>> execute(
    CommandContext context,
    RecordStockOutInput input,
  ) async {
    final RecordStockOutResult? replayed = _recordedCommands[context.commandId];
    if (replayed != null) {
      return Success<RecordStockOutResult>(replayed);
    }

    final ProductSnapshot? product = await catalogReader.findById(
      input.productId,
    );
    if (product == null) {
      return Failed<RecordStockOutResult>(
        UnknownProduct(productId: input.productId),
      );
    }

    if (product.isArchived) {
      return Failed<RecordStockOutResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }

    if (input.qty <= 0) {
      return Failed<RecordStockOutResult>(
        InvalidQuantity(productId: product.id, qty: input.qty),
      );
    }

    final StockMovementReason reason = _mapReason(input.reason);
    final String movementId = '${context.commandId}-out';

    final int movementQty = input.qty < 1
        ? input.qty.ceil()
        : input.qty.round();

    final StockMovement movement = StockMovement(
      id: movementId,
      productId: product.id,
      type: StockMovementType.manualOut,
      reason: reason,
      quantity: movementQty,
      createdAt: context.dateTime,
      note: input.note ?? 'Sortie vocale ${context.commandId}',
    );

    try {
      await recordStockOut(movement);
      final double newStock = product.stock - input.qty;
      final RecordStockOutResult result = (
        movementId: movementId,
        productId: product.id,
        productName: product.name,
        qty: input.qty,
        reason: input.reason,
        resultingStock: newStock,
      );
      _recordedCommands[context.commandId] = result;
      return Success<RecordStockOutResult>(result);
    } on StockMovementFailure catch (_) {
      return Failed<RecordStockOutResult>(
        InvalidQuantity(productId: product.id, qty: input.qty),
      );
    }
  }

  StockMovementReason _mapReason(String reasonStr) {
    return switch (reasonStr.toLowerCase()) {
      'loss' || 'perte' || 'perime' || 'avarie' => StockMovementReason.loss,
      'breakage' || 'casse' || 'abime' => StockMovementReason.breakage,
      'donation' || 'don' => StockMovementReason.donation,
      _ => StockMovementReason.manualAdjustment,
    };
  }
}
