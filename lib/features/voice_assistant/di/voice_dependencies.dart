import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/voice_flags.dart';
import '../data/catalog/catalog_fixture_loader.dart';
import '../data/catalog/in_memory_product_catalog.dart';
import '../data/handlers/call_journal.dart';
import '../data/handlers/mock/mock_voice_handlers.dart';
import '../domain/ports/handler_call_journal.dart';
import '../domain/ports/intent_handler.dart';

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
