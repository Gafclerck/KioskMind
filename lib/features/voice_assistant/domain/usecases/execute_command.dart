import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../dialog/dialog_manager.dart';
import '../entities/command_proposal.dart';
import '../entities/decision_outcome.dart';
import '../ports/command_context.dart';
import '../ports/command_id_factory.dart';
import '../ports/intent_registry.dart';
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
/// it through the [IntentRegistry]: it never sees Firestore, a document or a
/// feature, and it names no command. Its whole job is to find the binding the
/// proposal asks for, run it with the command context the contract asks for, and
/// open the undo window when the binding says the run left a sale to take back.
///
/// A proposal for a command nothing is bound to is a wiring error, and it says so
/// rather than doing nothing.
final class ExecuteCommand {
  const ExecuteCommand({
    required this.registry,
    required this.dialog,
    required this.clock,
    required this.ids,
  });

  /// Every command the module can run, indexed by intent.
  final IntentRegistry registry;

  final DialogManager dialog;
  final VoiceClock clock;
  final CommandIdFactory ids;

  Future<CommandExecution> run({
    required Decision decision,
    required CommandProposal proposal,
    CommandSource source = CommandSource.voice,
  }) async {
    if (!decision.executes) {
      return HeldCommand(decision);
    }
    final IntentBinding? binding = registry.bindingOf(proposal.intentId);
    if (binding == null) {
      throw StateError('Intent sans liaison enregistree: ${proposal.intentId}');
    }
    final Result<Object> result = await binding.call(
      proposal,
      _context(source),
    );
    _openUndoWindow(binding, result);
    return ExecutedCommand(result);
  }

  /// Opens the undo window when the binding declares the run left a sale.
  ///
  /// Only a sale the binding named can be taken back: a restock has no way back and
  /// does not pretend to have one, and a refused command leaves nothing behind.
  void _openUndoWindow(IntentBinding binding, Result<Object> result) {
    final Object? value = switch (result) {
      Success<Object>(:final Object value) => value,
      Failed<Object>() => null,
    };
    if (value == null) {
      return;
    }
    final String? saleId = binding.undoTarget(value);
    if (saleId != null) {
      dialog.registerUndo(saleId);
    }
  }

  CommandContext _context(CommandSource source) {
    return (commandId: ids.next(), dateTime: clock.now(), source: source);
  }
}
