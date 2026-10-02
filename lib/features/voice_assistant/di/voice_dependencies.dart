import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/voice_flags.dart';
import '../data/catalog/catalog_fixture_loader.dart';
import '../data/catalog/in_memory_product_catalog.dart';
import '../data/catalog/intent_catalog_loader.dart';
import '../data/clock/system_voice_clock.dart';
import '../data/commands/session_command_ids.dart';
import '../data/handlers/call_journal.dart';
import '../data/handlers/mock/mock_voice_handlers.dart';
import '../domain/dialog/dialog_manager.dart';
import '../domain/entities/intent_definition.dart';
import '../domain/entities/voice_config.dart';
import '../domain/ports/command_id_factory.dart';
import '../domain/ports/handler_call_journal.dart';
import '../domain/ports/intent_handler.dart';
import '../domain/ports/voice_clock.dart';
import '../domain/services/command_validator.dart';
import '../domain/services/decision_policy.dart';
import '../domain/usecases/execute_command.dart';
import '../domain/usecases/undo_last_command.dart';

/// Composition root of the voice module.
///
/// It is the single place that knows whether a handler is the in-memory mock or
/// the real use case, so the rest of the module never branches on that choice.
/// It lives inside the feature rather than in `core/di` because `core/` is
/// reserved for code two features or more share, and a core module must not
/// depend on a feature: wiring voice handlers from there would break both rules.
/// `core/di` stays free for genuinely cross-feature wiring.
///
/// This is not a fourth layer. It only assembles `domain` and `data`; the
/// `presentation` layer consumes the providers declared here and never imports
/// `data/` itself.

/// Whether the composition root wires the in-memory handlers.
///
/// Reads the build-time flag, and can be overridden per provider in tests, so
/// phase I can switch one intent at a time.
final Provider<bool> voiceUseMocksProvider = Provider<bool>(
  (Ref ref) => kVoiceUseMocks,
);

/// Where handler calls are recorded, for the routing metric and the tests.
final Provider<HandlerCallJournal> voiceCallJournalProvider =
    Provider<HandlerCallJournal>((Ref ref) => InMemoryCallJournal());

/// The product catalog the mocks work on, read from the bundled fixture.
final FutureProvider<InMemoryProductCatalog> voiceMockCatalogProvider =
    FutureProvider<InMemoryProductCatalog>((Ref ref) async {
      final String source = await rootBundle.loadString(catalogFixtureAsset);
      return InMemoryProductCatalog(parseCatalogFixture(source));
    });

/// The handlers the executor will call.
///
/// Throws when the build asks for real handlers: none exists yet, and failing
/// loudly beats a silent fallback to mocks in a demo meant to prove the real
/// path.
final FutureProvider<VoiceHandlers> voiceHandlersProvider =
    FutureProvider<VoiceHandlers>((Ref ref) async {
      if (!ref.watch(voiceUseMocksProvider)) {
        throw StateError(
          'VOICE_USE_MOCKS=false alors qu aucun handler reel n existe encore. '
          'Phase I du pipeline vocal.',
        );
      }
      return buildMockVoiceHandlers(
        catalog: await ref.watch(voiceMockCatalogProvider.future),
        journal: ref.watch(voiceCallJournalProvider),
      );
    });

/// The tunables, in one place so a test can replace all of them at once.
final Provider<VoiceConfig> voiceConfigProvider = Provider<VoiceConfig>(
  (Ref ref) => const VoiceConfig(),
);

/// The intent catalog, read from the bundled asset.
///
/// One instance per container: the catalog is validated on load and holds the risk
/// of every intent, which is what the decision policy reads.
final FutureProvider<IntentCatalog> voiceIntentsProvider =
    FutureProvider<IntentCatalog>(
      (Ref ref) async =>
          parseIntentCatalog(await rootBundle.loadString(intentCatalogAsset)),
    );

/// The device clock. Overridden wherever time must not pass.
final Provider<VoiceClock> voiceClockProvider = Provider<VoiceClock>(
  (Ref ref) => const SystemVoiceClock(),
);

/// Command identifiers, one sequence per container so a replay does not collide.
final Provider<CommandIdFactory> voiceCommandIdsProvider =
    Provider<CommandIdFactory>(
      (Ref ref) => SessionCommandIds(clock: ref.watch(voiceClockProvider)),
    );

/// The session state: the pending question, the undo window, the turn count.
///
/// One instance per container, because the session is what a second utterance reads.
/// A container per session is the presentation layer's business, and overriding this
/// provider is how a test replaces the whole session.
final Provider<DialogManager> voiceDialogProvider = Provider<DialogManager>(
  (Ref ref) => DialogManager(
    config: ref.watch(voiceConfigProvider),
    clock: ref.watch(voiceClockProvider),
  ),
);

/// What the module doubts on its own: a quantity or a price the catalog contradicts.
final Provider<CommandValidator> voiceCommandValidatorProvider =
    Provider<CommandValidator>(
      (Ref ref) => CommandValidator(config: ref.watch(voiceConfigProvider)),
    );

/// The one place where what was heard becomes what happens.
final FutureProvider<DecisionPolicy> voiceDecisionPolicyProvider =
    FutureProvider<DecisionPolicy>(
      (Ref ref) async =>
          DecisionPolicy(catalog: await ref.watch(voiceIntentsProvider.future)),
    );

/// The only path from a decision to a business use case.
final FutureProvider<ExecuteCommand> voiceExecuteCommandProvider =
    FutureProvider<ExecuteCommand>(
      (Ref ref) async => ExecuteCommand(
        handlers: await ref.watch(voiceHandlersProvider.future),
        dialog: ref.watch(voiceDialogProvider),
        clock: ref.watch(voiceClockProvider),
        ids: ref.watch(voiceCommandIdsProvider),
      ),
    );

/// Taking back the last write of the session.
final FutureProvider<UndoLastCommand> voiceUndoLastCommandProvider =
    FutureProvider<UndoLastCommand>(
      (Ref ref) async => UndoLastCommand(
        handlers: await ref.watch(voiceHandlersProvider.future),
        dialog: ref.watch(voiceDialogProvider),
        clock: ref.watch(voiceClockProvider),
        ids: ref.watch(voiceCommandIdsProvider),
      ),
    );
