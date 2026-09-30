import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/constants/voice_flags.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_providers.dart';

/// The catalog the composition root would build, without loading the asset.
InMemoryProductCatalog buildCatalogFromDisk() {
  return InMemoryProductCatalog(
    parseCatalogFixture(File(catalogFixtureAsset).readAsStringSync()),
  );
}

ProviderContainer buildContainer({
  required InMemoryProductCatalog catalog,
  bool useMocks = true,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      voiceUseMocksProvider.overrideWithValue(useMocks),
      voiceMockCatalogProvider.overrideWith((Ref ref) async => catalog),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // The catalog provider reads the bundled asset, which needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the mock flag', () {
    test(
      'defaults to true so the demo runs before the real use cases land',
      () {
        expect(kVoiceUseMocks, isTrue);
      },
    );

    test('is what the provider hands out with no override', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(voiceUseMocksProvider), kVoiceUseMocks);
    });
  });

  group('the bundled catalog provider', () {
    test('reads the declared asset and hands a usable shop over', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final InMemoryProductCatalog catalog = await container.read(
        voiceMockCatalogProvider.future,
      );

      expect(await catalog.readActiveProducts(), isNotEmpty);
      expect(await catalog.findById('p_sucre'), isNotNull);
    });
  });

  group('the composition root', () {
    test('wires the four handlers when mocks are requested', () async {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      final VoiceHandlers handlers = await container.read(
        voiceHandlersProvider.future,
      );

      expect(handlers.recordSale, isNotNull);
      expect(handlers.recordRestock, isNotNull);
      expect(handlers.queryStock, isNotNull);
      expect(handlers.cancelLastSale, isNotNull);
    });

    test('fails loudly when real handlers are requested, none exists yet', () {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
        useMocks: false,
      );

      expect(
        () => container.read(voiceHandlersProvider.future),
        throwsA(isA<StateError>()),
      );
    });

    test('records every call into the shared journal', () async {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );
      final VoiceHandlers handlers = await container.read(
        voiceHandlersProvider.future,
      );
      final HandlerCallJournal journal = container.read(
        voiceCallJournalProvider,
      );

      final CommandContext voice = (
        commandId: 'cmd-1',
        dateTime: DateTime(2026, 3, 1, 10),
        source: CommandSource.voice,
      );
      await handlers.recordSale!.execute(
        voice,
        const SaleIntentInput(
          items: <SaleIntentLine>[
            SaleIntentLine(productId: 'p_sucre', productName: 'Sucre', qty: 2),
          ],
        ),
      );

      expect(journal.calls, hasLength(1));
      expect(journal.calls.single.intentId, 'record_sale');
      expect(journal.calls.single.handlerArgs, <String, Object?>{
        'items': <Map<String, Object?>>[
          <String, Object?>{'productId': 'p_sucre', 'qty': 2},
        ],
      });
    });

    test('shares one journal across every handler', () async {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );
      final VoiceHandlers handlers = await container.read(
        voiceHandlersProvider.future,
      );
      final HandlerCallJournal journal = container.read(
        voiceCallJournalProvider,
      );
      final CommandContext voice = (
        commandId: 'cmd-1',
        dateTime: DateTime(2026, 3, 1, 10),
        source: CommandSource.voice,
      );

      await handlers.queryStock!.execute(
        voice,
        const QueryStockInput(productId: 'p_sucre'),
      );
      await handlers.queryStock!.execute(
        voice,
        const QueryStockInput(productId: 'p_riz'),
      );

      expect(
        journal.calls.map((HandlerCall call) => call.intentId).toList(),
        <String>['query_stock', 'query_stock'],
      );
    });

    test('exposes one journal instance per container', () {
      final ProviderContainer first = buildContainer(
        catalog: buildCatalogFromDisk(),
      );
      final ProviderContainer second = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      expect(
        first.read(voiceCallJournalProvider),
        isNot(same(second.read(voiceCallJournalProvider))),
      );
    });
  });

  group('buildMockVoiceHandlers', () {
    test('gives every handler the intent id of the catalog', () async {
      final InMemoryProductCatalog catalog = buildCatalogFromDisk();
      final VoiceHandlers handlers = buildMockVoiceHandlers(
        catalog: catalog,
        journal: InMemoryCallJournal(),
      );

      expect(handlers.recordSale!.intentId, 'record_sale');
      expect(handlers.recordRestock!.intentId, 'record_restock');
      expect(handlers.queryStock!.intentId, 'query_stock');
      expect(handlers.cancelLastSale!.intentId, 'cancel_last_sale');
    });
  });
}
