import '../../../../core/usecase/result.dart';
import '../../domain/entities/intent_input.dart';
import '../../domain/ports/command_context.dart';
import '../../domain/ports/handler_call_journal.dart';
import '../../domain/ports/intent_handler.dart';
import 'canonical_arguments.dart';

/// Records every call that passes through, so the routing metric compares real
/// handler calls with the golden set (D9).
///
/// A decorator rather than a responsibility of the mocks: the same evidence is
/// needed in phase I, where the handlers call Firestore, and neither the mocks
/// nor the real handlers should know they are observed.
final class JournalingIntentHandler<TInput extends IntentInput, TOutput>
    implements IntentHandler<TInput, TOutput> {
  JournalingIntentHandler(this._inner, this._journal);

  final IntentHandler<TInput, TOutput> _inner;
  final HandlerCallJournal _journal;

  @override
  String get intentId => _inner.intentId;

  @override
  Future<Result<TOutput>> execute(CommandContext context, TInput input) {
    _journal.record((
      intentId: intentId,
      handlerArgs: canonicalArguments(input.toArguments()),
    ));
    return _inner.execute(context, input);
  }
}
