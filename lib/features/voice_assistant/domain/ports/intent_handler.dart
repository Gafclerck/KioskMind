import '../../../../core/usecase/result.dart';
import '../entities/intent_input.dart';
import '../entities/intent_result.dart';
import 'command_context.dart';

/// Port of a business use case the voice module can call.
///
/// One handler per intent, and one intent per handler. Implementations live in
/// `data/handlers`: in-memory mocks now, real use cases in phase I. The voice
/// module never sees a Firestore document.
abstract interface class IntentHandler<TInput extends IntentInput, TOutput> {
  /// Must match the `handler` of an entry in `voice/intent_catalog.json`.
  String get intentId;

  Future<Result<TOutput>> execute(CommandContext context, TInput input);
}

/// Every intent the module can route, in catalog order.
///
/// The catalog validates its `handler` values against this set, so a command
/// cannot be described in `voice/intent_catalog.json` without a port able to
/// execute it. Adding a command means adding it here, in the catalog, and
/// writing the handler: no other file has to change.
const Set<String> kSupportedIntentIds = <String>{
  'record_sale',
  'record_restock',
  'query_stock',
  'cancel_last_sale',
};

typedef RecordSaleHandler = IntentHandler<SaleIntentInput, RecordSaleResult>;
typedef RecordRestockHandler =
    IntentHandler<RestockIntentInput, RecordRestockResult>;

typedef QueryStockHandler = IntentHandler<QueryStockInput, QueryStockResult>;

typedef CancelLastSaleHandler =
    IntentHandler<CancelLastSaleInput, CancelLastSaleResult>;

/// The handler ports the executor may call, at most one per intent.
///
/// A holder rather than a heterogeneous list: a `List<IntentHandler<dynamic,
/// dynamic>>` would erase the input and output types that make each call site
/// checkable.
final class VoiceHandlers {
  const VoiceHandlers({
    this.recordSale,
    this.recordRestock,
    this.queryStock,
    this.cancelLastSale,
  });

  final RecordSaleHandler? recordSale;
  final RecordRestockHandler? recordRestock;
  final QueryStockHandler? queryStock;
  final CancelLastSaleHandler? cancelLastSale;
}
