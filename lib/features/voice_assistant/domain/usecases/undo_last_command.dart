import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../dialog/dialog_manager.dart';
import '../entities/intent_input.dart';
import '../entities/intent_result.dart';
import '../ports/command_context.dart';
import '../ports/command_id_factory.dart';
import '../ports/intent_handler.dart';
import '../ports/voice_clock.dart';

/// Takes back the last write of the session, through the cancellation handler.
///
/// Undo is not a deletion and not a new command type: it is the existing
/// `cancel_last_sale` intent, which is why the window is the session's and why the
/// contract suite already covers what it does to the stock. What this adds is the
/// window: past it, there is nothing left to undo, and that is reported as a named
/// failure rather than as a silent no-op.
///
/// This is the only place a cancellation is run. Both ways of asking for one come
/// here - the word the merchant speaks and the button on the undo banner - so they
/// cannot drift apart.
final class UndoLastCommand {
  const UndoLastCommand({
    required this.handlers,
    required this.dialog,
    required this.clock,
    required this.ids,
  });

  final VoiceHandlers handlers;
  final DialogManager dialog;
  final VoiceClock clock;
  final CommandIdFactory ids;

  Future<Result<CancelLastSaleResult>> run({
    CommandSource source = CommandSource.voice,
  }) async {
    final CancelLastSaleHandler? handler = handlers.cancelLastSale;
    if (handler == null) {
      return const Failed<CancelLastSaleResult>(NothingToUndo());
    }
    final String? saleId = dialog.takeUndoable();
    if (saleId == null) {
      return const Failed<CancelLastSaleResult>(NothingToUndo());
    }
    final Result<CancelLastSaleResult> result = await handler.execute((
      commandId: ids.next(),
      dateTime: clock.now(),
      source: source,
    ), CancelLastSaleInput(saleId: saleId));
    if (result is Failed<CancelLastSaleResult>) {
      // The window was consumed by an attempt that did not happen: giving it back
      // would let a merchant retry into the same failure, and taking it away for
      // good would hide a sale that is still cancellable.
      dialog.registerUndo(saleId);
    }
    return result;
  }
}
