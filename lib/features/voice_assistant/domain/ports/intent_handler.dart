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

/// The intent the session voice owns the identifier of.
///
/// Named here because the intent carries no slot: the sale it targets comes from the
/// undo window, and the binding in `data/commands/voice_bindings.dart` is where that
/// is turned into a call.
const String kCancelLastSaleIntent = 'cancel_last_sale';

/// Every intent the module can route, in catalog order.
///
/// The catalog validates its `handler` values against this set, so a command
/// cannot be described in `voice/intent_catalog.json` without a port able to
/// execute it.
///
/// Adding a command means a catalog entry, a handler, and a binding registered at
/// composition: the executor, the parser and the validator stay as they are. An
/// intent whose input type is not declared here needs a new [IntentHandler] type,
/// which is why this set and the handler field of [VoiceHandlers] still exist.
const Set<String> kSupportedIntentIds = <String>{
  'record_sale',
  'record_restock',
  'query_stock',
  kCancelLastSaleIntent,
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
