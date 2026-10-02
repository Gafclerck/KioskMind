import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/intent_input.dart';
import '../../domain/entities/intent_result.dart';
import '../../domain/entities/slot.dart';
import '../../domain/ports/command_context.dart';
import '../../domain/ports/intent_handler.dart';
import '../../domain/ports/intent_registry.dart';
import '../../domain/usecases/undo_last_command.dart';

/// The bindings of the four shipped commands.
///
/// The one place that says how a proposal becomes the typed input its handler
/// takes, and which success leaves a sale to take back. The executor, the parser and
/// the validator know none of it, which is what lets a command be added here and in
/// the catalog without touching them.
///
/// Phase I replaces this file, one binding at a time, as the real use cases land.
List<IntentBinding> buildVoiceBindings({
  required VoiceHandlers handlers,
  required UndoLastCommand undo,
}) {
  return <IntentBinding>[
    if (handlers.recordSale case final RecordSaleHandler sale)
      IntentBinding.bind<SaleIntentInput, RecordSaleResult>(
        intentId: sale.intentId,
        handler: sale,
        input: _saleInput,
        undoTarget: (RecordSaleResult result) => result.saleId,
      ),
    if (handlers.recordRestock case final RecordRestockHandler restock)
      IntentBinding.bind<RestockIntentInput, RecordRestockResult>(
        intentId: restock.intentId,
        handler: restock,
        input: _restockInput,
      ),
    if (handlers.queryStock case final QueryStockHandler query)
      IntentBinding.bind<QueryStockInput, QueryStockResult>(
        intentId: query.intentId,
        handler: query,
        input: _queryInput,
      ),
    IntentBinding.ofCall(
      intentId: kCancelLastSaleIntent,
      // The identifier comes from the undo window, so an utterance can only ever
      // target the sale just made (contract A12). Running it here rather than in the
      // executor is what keeps it identical to the undo button: both call
      // UndoLastCommand, and a cancellation the shop refused gives the window back
      // whichever way it was asked for.
      call: (CommandProposal proposal, CommandContext context) =>
          undo.run(source: context.source),
      undoTarget: (Object result) => null,
    ),
  ];
}

/// The lines of a sale, in spoken order, with the price as a doubt signal only.
Result<SaleIntentInput> _saleInput(CommandProposal proposal) {
  return Success<SaleIntentInput>(
    SaleIntentInput(
      items: <SaleIntentLine>[
        for (final ItemMention line in _items(proposal))
          SaleIntentLine(
            productId: line.product.id,
            productName: line.product.name,
            qty: line.qty,
            spokenUnitPrice: line.spokenAmount,
          ),
      ],
    ),
  );
}

/// The lines of a restock, in spoken order.
Result<RestockIntentInput> _restockInput(CommandProposal proposal) {
  return Success<RestockIntentInput>(
    RestockIntentInput(
      items: <RestockIntentLine>[
        for (final ItemMention line in _items(proposal))
          RestockIntentLine(
            productId: line.product.id,
            productName: line.product.name,
            qty: line.qty,
            spokenUnitCost: line.spokenAmount,
          ),
      ],
    ),
  );
}

/// The product asked about, or a named failure when the proposal carries none.
///
/// A read command with no product in it is not a call with an empty argument: it is
/// a question the module could not answer, and the handler is not called.
Result<QueryStockInput> _queryInput(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  if (productId == null) {
    return Failed<QueryStockInput>(
      UnknownProduct(productId: '', productName: null),
    );
  }
  return Success<QueryStockInput>(QueryStockInput(productId: productId));
}

List<ItemMention> _items(CommandProposal proposal) {
  return proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
      const <ItemMention>[];
}
