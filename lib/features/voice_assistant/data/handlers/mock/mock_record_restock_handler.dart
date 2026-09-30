import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../catalog/in_memory_product_catalog.dart';

/// Mock of the restock use case, backed by the in-memory store.
///
/// Movement identifiers are derived from the command identifier, so a replay
/// produces the same identifiers instead of a second movement.
final class MockRecordRestockHandler implements RecordRestockHandler {
  MockRecordRestockHandler(this._catalog);

  final InMemoryProductCatalog _catalog;

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

    final List<RestockLineResult> lines = <RestockLineResult>[];
    for (final RestockIntentLine item in input.items) {
      switch (_line(item)) {
        case Failed<RestockLineResult>(:final Failure failure):
          return Failed<RecordRestockResult>(failure);
        case Success<RestockLineResult>(:final RestockLineResult value):
          lines.add(value);
      }
    }

    final RecordRestockResult result = (
      movementIds: <String>[
        for (int index = 0; index < lines.length; index++)
          '${context.commandId}-$index',
      ],
      lines: lines,
    );
    _catalog.applyRestock(context, result);
    return Success<RecordRestockResult>(result);
  }

  Result<RestockLineResult> _line(RestockIntentLine item) {
    final ProductSnapshot? product = _catalog.productById(item.productId);
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
