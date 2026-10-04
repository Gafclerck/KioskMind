import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/constants/voice_flags.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/clock/system_voice_clock.dart';
import 'package:kiosk_mind/features/voice_assistant/data/commands/session_command_ids.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/handler_call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/handle_utterance.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/stock_movement_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/record_stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/sales_repository.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/cancel_sale.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/record_sale.dart';
import 'package:kiosk_mind/features/sales/presentation/providers/sales_provider.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';

import 'fake_clock.dart';
import 'rule_parser_harness.dart' show fixtureProducts;

final class _FakeSalesRepo implements SalesRepository {
  @override
  Future<Sale> recordSale(Sale sale) async => sale;

  @override
  Future<Sale> cancelSale(String saleId) async => Sale(
    id: saleId,
    dateTime: DateTime(2026, 3, 1),
    createdAt: DateTime(2026, 3, 1),
    total: 0,
    items: const <SaleItem>[],
    source: 'VOICE',
    status: 'CANCELLED',
  );

  @override
  Future<List<Sale>> getSalesHistory() async => const <Sale>[];

  @override
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async => const <Sale>[];
}

final class _FakeStockMovementRepo implements StockMovementRepository {
  @override
  Future<void> recordMovement(StockMovement movement) async {}

  @override
  Stream<List<StockMovement>> watchMovements(String productId) =>
      const Stream<List<StockMovement>>.empty();
}

/// The catalog the composition root would build, without loading the asset.
InMemoryProductCatalog buildCatalogFromDisk() {
  return InMemoryProductCatalog(
    parseCatalogFixture(File(catalogFixtureAsset).readAsStringSync()),
  );
}

/// The shipped product [id], for a proposal the test builds by hand.
ProductSnapshot fixtureProduct(String id) {
  return fixtureProducts().firstWhere(
    (ProductSnapshot product) => product.id == id,
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

    test('wires the four real handlers when mocks are disabled', () async {
      final InMemoryProductCatalog catalog = buildCatalogFromDisk();
      final _FakeSalesRepo salesRepo = _FakeSalesRepo();
      final _FakeStockMovementRepo stockRepo = _FakeStockMovementRepo();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          voiceUseMocksProvider.overrideWithValue(false),
          voiceCatalogReaderProvider.overrideWith((Ref ref) async => catalog),
          recordSaleProvider.overrideWithValue(RecordSale(salesRepo)),
          cancelSaleProvider.overrideWithValue(CancelSale(salesRepo)),
          recordStockInProvider.overrideWithValue(RecordStockIn(stockRepo)),
        ],
      );
      addTearDown(container.dispose);

      final VoiceHandlers handlers = await container.read(
        voiceHandlersProvider.future,
      );

      expect(handlers.recordSale, isNotNull);
      expect(handlers.recordRestock, isNotNull);
      expect(handlers.queryStock, isNotNull);
      expect(handlers.cancelLastSale, isNotNull);
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

  group('the session providers', () {
    test('the clock is the device one, and replaceable', () {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      expect(container.read(voiceClockProvider), isA<SystemVoiceClock>());

      final FakeClock frozen = FakeClock(DateTime(2026, 3, 1, 10));
      final ProviderContainer timed = ProviderContainer(
        overrides: <Override>[voiceClockProvider.overrideWithValue(frozen)],
      );
      addTearDown(timed.dispose);

      expect(timed.read(voiceClockProvider).now(), DateTime(2026, 3, 1, 10));
    });

    test('the command ids come from one sequence per container', () {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );
      final CommandIdFactory ids = container.read(voiceCommandIdsProvider);

      final String first = ids.next();
      final String second = ids.next();

      expect(first, isNot(second));
      expect(first, startsWith('${SessionCommandIds.prefix}-'));
      expect(container.read(voiceCommandIdsProvider), same(ids));
    });

    test('one dialog per container, so the session is one session', () {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      expect(
        container.read(voiceDialogProvider),
        same(container.read(voiceDialogProvider)),
      );
    });

    test('the validator reads the tunables the config gives it', () async {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      expect(
        await container.read(voiceCommandValidatorProvider.future),
        isA<CommandValidator>(),
      );
    });

    test('the policy is built from the bundled catalog', () async {
      final ProviderContainer container = buildContainer(
        catalog: buildCatalogFromDisk(),
      );

      final IntentCatalog intents = await container.read(
        voiceIntentsProvider.future,
      );
      final DecisionPolicy policy = await container.read(
        voiceDecisionPolicyProvider.future,
      );

      expect(intents.byId('record_sale'), isNotNull);
      expect(
        policy
            .decide(
              const CommandProposal.rules(
                intentId: 'record_sale',
                slots: <Slot>[],
              ),
            )
            .outcome,
        DecisionOutcome.executeWithUndo,
      );
    });

    test(
      'the executor and the undo share one dialog and one id sequence',
      () async {
        final ProviderContainer container = buildContainer(
          catalog: buildCatalogFromDisk(),
        );

        final ExecuteCommand execute = await container.read(
          voiceExecuteCommandProvider.future,
        );
        final UndoLastCommand undo = await container.read(
          voiceUndoLastCommandProvider.future,
        );
        final DialogManager dialog = container.read(voiceDialogProvider);

        await execute.run(
          decision: const Decision(DecisionOutcome.executeWithUndo),
          proposal: CommandProposal.rules(
            intentId: 'record_sale',
            slots: <Slot>[
              Slot(
                name: 'items',
                value: <ItemMention>[
                  ItemMention(product: fixtureProduct('p_sucre'), qty: 2),
                ],
              ),
            ],
          ),
        );

        expect(dialog.undoSaleId, isNotNull);
        expect(await undo.run(), isA<Success<CancelLastSaleResult>>());
      },
    );

    test('wires the whole turn, from the words to the handler', () async {
      final InMemoryProductCatalog catalog = buildCatalogFromDisk();
      final ProviderContainer container = buildContainer(catalog: catalog);

      final HandleUtterance turn = await container.read(
        voiceHandleUtteranceProvider.future,
      );

      final VoiceTurn sale = await turn.run('vendu deux sucres');

      expect(sale.decision.outcome, DecisionOutcome.executeWithUndo);
      expect(
        container.read(voiceCallJournalProvider).calls.single.intentId,
        'record_sale',
      );
    });

    test(
      'wires the turn so an answer completes the utterance it follows',
      () async {
        final ProviderContainer container = buildContainer(
          catalog: buildCatalogFromDisk(),
        );

        final HandleUtterance turn = await container.read(
          voiceHandleUtteranceProvider.future,
        );

        await turn.run('vendu deux');
        await turn.run('sucre');

        expect(
          container.read(voiceCallJournalProvider).calls.single.handlerArgs,
          <String, Object?>{
            'items': <Object?>[
              <String, Object?>{'productId': 'p_sucre', 'qty': 2},
            ],
          },
        );
      },
    );

    test(
      'gives the turn one dialog, so the session is the container one',
      () async {
        final ProviderContainer container = buildContainer(
          catalog: buildCatalogFromDisk(),
        );

        final HandleUtterance turn = await container.read(
          voiceHandleUtteranceProvider.future,
        );
        await turn.run('vendu deux');

        expect(container.read(voiceDialogProvider).pending, isNotNull);
      },
    );

    test(
      'the parser chain reads the bundled catalog and the tunables',
      () async {
        final ProviderContainer container = buildContainer(
          catalog: buildCatalogFromDisk(),
        );

        final RuleBasedParser parser = await container.read(
          voiceRuleBasedParserProvider.future,
        );
        final ProductResolver resolver = await container.read(
          voiceProductResolverProvider.future,
        );
        final TextNormalizer normalizer = container.read(
          voiceNormalizerProvider,
        );

        expect(parser.normalizer, same(normalizer));
        expect(
          resolver.matchAt(<String>['sucre'], 0)?.resolution.product?.id,
          'p_sucre',
        );
        expect(container.read(voiceNormalizerProvider), same(normalizer));
      },
    );
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
