import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../dialog/dialog_manager.dart';
import '../entities/command_proposal.dart';
import '../entities/decision_outcome.dart';
import '../entities/intent_input.dart';
import '../entities/intent_result.dart';
import '../entities/slot.dart';
import '../ports/command_context.dart';
import '../ports/command_id_factory.dart';
import '../ports/intent_handler.dart';
import '../ports/voice_clock.dart';

/// What running one command produced.
///
/// A sealed result rather than a nullable failure so a caller cannot read a
/// failure as a success: [isExecuted] says whether the handler ran, and
/// [failure] says why it refused when it did not.
sealed class CommandExecution {
  const CommandExecution();

  /// The command reached its handler.
  bool get isExecuted;

  /// The typed failure, or null when the command ran.
  Failure? get failure;

  /// What the handler answered, or null when none was called. The record type is
  /// carried inside the result, so a caller that knows the intent reads it back
  /// with a pattern match rather than through a common shape every intent would
  /// have to invent.
  Result<Object>? get result => null;
}

/// The handler ran and answered.
final class ExecutedCommand extends CommandExecution {
  const ExecutedCommand(this.result);

  @override
  final Result<Object> result;

  @override
  bool get isExecuted => true;

  @override
  Failure? get failure => switch (result) {
    Failed<Object>(:final Failure failure) => failure,
    Success<Object>() => null,
  };
}

/// The command was held: the policy asked a question or refused it.
final class HeldCommand extends CommandExecution {
  const HeldCommand(this.decision);

  final Decision decision;

  @override
  bool get isExecuted => false;

  @override
  Failure? get failure => null;

  @override
  String toString() => 'HeldCommand($decision)';
}

/// Runs a proposal the policy decided to run.
///
/// This is the only place the voice module calls a business use case, and it does
/// it through an [IntentHandler] port: it never sees Firestore, a document or a
/// feature. Its whole job is to turn a proposal into the one typed input its
/// intent declares, with the command context the contract asks for, and to
/// register the undo window when a write happened.
final class ExecuteCommand {
  const ExecuteCommand({
    required this.handlers,
    required this.dialog,
    required this.clock,
    required this.ids,
  });

  final VoiceHandlers handlers;
  final DialogManager dialog;
  final VoiceClock clock;
  final CommandIdFactory ids;

  Future<CommandExecution> run({
    required Decision decision,
    required CommandProposal proposal,
    CommandSource source = CommandSource.voice,
  }) {
    if (!decision.executes) {
      return Future<CommandExecution>.value(HeldCommand(decision));
    }
    final String intentId = proposal.intentId;
    return switch (intentId) {
      'record_sale' => _runSale(proposal, source),
      'record_restock' => _runRestock(proposal, source),
      'query_stock' => _runQuery(proposal, source),
      'cancel_last_sale' => _runCancel(proposal, source),
      _ => Future<CommandExecution>.error(
        StateError('Intent sans handler branche: $intentId'),
      ),
    };
  }

  Future<CommandExecution> _runSale(
    CommandProposal proposal,
    CommandSource source,
  ) {
    final RecordSaleHandler? handler = handlers.recordSale;
    if (handler == null) {
      return Future<CommandExecution>.error(
        StateError('Handler non branche: record_sale'),
      );
    }
    return _dispatch(
      handler.execute(
        _context(source),
        SaleIntentInput(items: _saleLines(proposal)),
      ),
    );
  }

  Future<CommandExecution> _runRestock(
    CommandProposal proposal,
    CommandSource source,
  ) {
    final RecordRestockHandler? handler = handlers.recordRestock;
    if (handler == null) {
      return Future<CommandExecution>.error(
        StateError('Handler non branche: record_restock'),
      );
    }
    return _dispatch(
      handler.execute(
        _context(source),
        RestockIntentInput(items: _restockLines(proposal)),
      ),
    );
  }

  Future<CommandExecution> _runQuery(
    CommandProposal proposal,
    CommandSource source,
  ) {
    final QueryStockHandler? handler = handlers.queryStock;
    final String? productId = proposal.valueOf<String>('productId');
    if (handler == null) {
      return Future<CommandExecution>.error(
        StateError('Handler non branche: query_stock'),
      );
    }
    if (productId == null) {
      return Future<CommandExecution>.value(
        ExecutedCommand(
          Failed<QueryStockResult>(
            UnknownProduct(productId: '', productName: null),
          ),
        ),
      );
    }
    return _dispatch(
      handler.execute(_context(source), QueryStockInput(productId: productId)),
    );
  }

  /// Cancels the sale the session holds.
  ///
  /// The intent has no slot of its own: the identifier comes from the undo window,
  /// so an utterance can only ever target the sale just made (contract A12).
  Future<CommandExecution> _runCancel(
    CommandProposal proposal,
    CommandSource source,
  ) {
    final CancelLastSaleHandler? handler = handlers.cancelLastSale;
    if (handler == null) {
      return Future<CommandExecution>.error(
        StateError('Handler non branche: cancel_last_sale'),
      );
    }
    final String? saleId = dialog.takeUndoable();
    if (saleId == null) {
      return Future<CommandExecution>.value(
        ExecutedCommand(Failed<CancelLastSaleResult>(const NothingToUndo())),
      );
    }
    return _dispatch(
      handler.execute(_context(source), CancelLastSaleInput(saleId: saleId)),
    );
  }

  /// Registers the undo window a successful write opens.
  ///
  /// Only a sale: a restock has nothing to take back through the cancellation
  /// handler, which knows about sales and about nothing else.
  /// Registers the undo window a successful sale opens.
  ///
  /// Only a sale: the cancellation handler knows about sales and about nothing
  /// else, so a restock has no way back and does not pretend to have one.
  Future<CommandExecution> _dispatch<T>(Future<Result<T>> call) async {
    final Result<T> result = await call;
    final Object? value = switch (result) {
      Success<T>(:final T value) => value,
      Failed<T>() => null,
    };
    if (value is RecordSaleResult) {
      dialog.registerUndo(value.saleId);
    }
    // Every result type is already an Object, so this only lifts the generic
    // argument; the record itself is untouched.
    return ExecutedCommand(result as Result<Object>);
  }

  CommandContext _context(CommandSource source) {
    return (commandId: ids.next(), dateTime: clock.now(), source: source);
  }

  List<SaleIntentLine> _saleLines(CommandProposal proposal) {
    return <SaleIntentLine>[
      for (final ItemMention line in _items(proposal))
        SaleIntentLine(
          productId: line.product.id,
          productName: line.product.name,
          qty: line.qty,
          spokenUnitPrice: line.spokenAmount,
        ),
    ];
  }

  List<RestockIntentLine> _restockLines(CommandProposal proposal) {
    return <RestockIntentLine>[
      for (final ItemMention line in _items(proposal))
        RestockIntentLine(
          productId: line.product.id,
          productName: line.product.name,
          qty: line.qty,
          spokenUnitCost: line.spokenAmount,
        ),
    ];
  }

  List<ItemMention> _items(CommandProposal proposal) {
    return proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
        const <ItemMention>[];
  }
}
