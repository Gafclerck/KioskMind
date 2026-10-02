import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/result.dart';
import '../entities/command_proposal.dart';
import '../entities/intent_definition.dart';
import '../entities/intent_input.dart';
import 'command_context.dart';
import 'intent_handler.dart';

/// One command, as the executor needs it: how to build its input, how to run it,
/// and what a success leaves behind.
///
/// Everything the executor has to know about a command is here, so it never names
/// one: it looks the binding up by identifier and applies what the binding
/// declares. A new command is a new binding, registered at composition.
final class IntentBinding {
  const IntentBinding._({
    required this.intentId,
    required this.call,
    required this.undoTarget,
  });

  /// Binds [handler] to the intent it executes.
  ///
  /// [input] reads the typed input out of the proposal and may refuse it, so an
  /// intent decides for itself what it does with a proposal that lacks what it
  /// needs, and the executor stays the same. [undoTarget] reads the identifier of
  /// the sale a success can take back, or is null when the intent leaves nothing
  /// to take back.
  ///
  /// The types are checked here, where the handler and the input are named, and
  /// erased before the binding stores them. [call] carries that one cast: the
  /// result comes from the handler this binding was registered for.
  static IntentBinding bind<TInput extends IntentInput, TOutput>({
    required String intentId,
    required IntentHandler<TInput, TOutput> handler,
    required Result<TInput> Function(CommandProposal proposal) input,
    String? Function(TOutput result)? undoTarget,
  }) {
    return IntentBinding._(
      intentId: intentId,
      call: (CommandProposal proposal, CommandContext context) async {
        final Result<TInput> built = input(proposal);
        return switch (built) {
          Failed<TInput>(:final Failure failure) => Failed<Object>(failure),
          Success<TInput>(:final TInput value) =>
            (await handler.execute(context, value)) as Result<Object>,
        };
      },
      undoTarget: (Object result) => undoTarget?.call(result as TOutput),
    );
  }

  /// Binds a call that is not a handler, such as a use case of its own.
  ///
  /// The cancellation is one: it goes through the undo use case rather than through
  /// a handler, and the binding keeps that decision in one place.
  factory IntentBinding.ofCall({
    required String intentId,
    required Future<Result<Object>> Function(
      CommandProposal proposal,
      CommandContext context,
    )
    call,
    String? Function(Object result)? undoTarget,
  }) {
    return IntentBinding._(
      intentId: intentId,
      call: call,
      undoTarget: undoTarget ?? ((Object _) => null),
    );
  }

  final String intentId;

  /// Runs the command, or refuses it with a typed failure.
  final Future<Result<Object>> Function(
    CommandProposal proposal,
    CommandContext context,
  )
  call;

  /// The sale a successful run can take back, or null when it leaves nothing.
  final String? Function(Object result) undoTarget;
}

/// The bindings, indexed by intent.
///
/// Built at composition and read by the executor. Two bindings for the same intent
/// is a wiring mistake, not a last one wins: the second would silently replace the
/// first.
final class IntentRegistry {
  factory IntentRegistry(List<IntentBinding> bindings) {
    final Map<String, IntentBinding> byId = <String, IntentBinding>{};
    for (final IntentBinding binding in bindings) {
      if (byId.containsKey(binding.intentId)) {
        throw StateError(
          'Deux liaisons enregistrees pour l intent "${binding.intentId}"',
        );
      }
      byId[binding.intentId] = binding;
    }
    return IntentRegistry._(byId);
  }

  const IntentRegistry._(this._bindings);

  final Map<String, IntentBinding> _bindings;

  /// The binding for [intentId], or null when the module cannot run that command.
  IntentBinding? bindingOf(String intentId) => _bindings[intentId];

  /// Identifiers the registry can run, in the order they were registered.
  List<String> get ids => _bindings.keys.toList();

  /// Refuses a registry that cannot run every declared command, or that runs one the
  /// catalog does not describe.
  ///
  /// A command described but unbound would be understood, decided and then refused
  /// as a wiring error; a command bound but undescribed would be reachable without
  /// the parser, the policy or the test set ever knowing it exists.
  void assertCovers(IntentCatalog catalog) {
    final Set<String> declared = catalog.ids.toSet();
    final Set<String> missing = declared.difference(ids.toSet());
    final Set<String> extra = ids.toSet().difference(declared);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw StateError(
        'Le registre et le catalogue ne coincident pas. '
        'Sans liaison: ${((missing.toList())..sort()).join(', ')}. '
        'Sans declaration: ${((extra.toList())..sort()).join(', ')}.',
      );
    }
  }
}
