import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/constants/voice_flags.dart';
import '../../data/catalog/catalog_fixture_loader.dart';
import '../../data/catalog/in_memory_product_catalog.dart';
import '../../data/handlers/call_journal.dart';
import '../../data/handlers/mock/mock_voice_handlers.dart';
import '../../domain/ports/handler_call_journal.dart';
import '../../domain/ports/intent_handler.dart';

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
