import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations_fr.dart';
import 'package:kiosk_mind/features/export_reporting/domain/models/export_file.dart';
import 'package:kiosk_mind/features/export_reporting/domain/models/export_format.dart';
import 'package:kiosk_mind/features/export_reporting/domain/services/export_generator.dart';
import 'package:kiosk_mind/features/export_reporting/domain/services/share_export_gateway.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/stock_movement_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/create_product.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/record_stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/update_product.dart';
import 'package:kiosk_mind/features/sales/domain/entities/daily_stats.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/daily_stats_repository.dart';
import 'package:kiosk_mind/features/sales/domain/repositories/sales_repository.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/get_sales_dashboard.dart';
import 'package:kiosk_mind/features/sales/domain/usecases/get_sales_history.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/data/commands/voice_bindings.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_create_product_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_export_report_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_navigate_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_business_info_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_daily_stats_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_low_stock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_product_price_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_sales_history_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_record_restock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_record_stock_out_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_update_product_price_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/remote_cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/clarification_slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/voice_config.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_registry.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/spoken_product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_application.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_message.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_recap.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_message_text.dart';

import 'fake_clock.dart';

/// Resolves a spoken name against the same products the reader was given.
///
/// [AnswerApplication] needs one resolved name rather than the catalog itself, so
/// the port is narrowed here. This double matches a name or an alias exactly, which
/// is all the confirmations in this group need: a yes or a no settles a doubt
/// without naming anything.
final class _SpokenNameResolver implements SpokenProductResolver {
  const _SpokenNameResolver(this._products);

  final List<ProductSnapshot> _products;

  @override
  ProductSnapshot? resolve(String spokenName) {
    final String spoken = spokenName.toLowerCase();
    for (final ProductSnapshot product in _products) {
      if (product.name.toLowerCase() == spoken) {
        return product;
      }
      if (product.aliases.any(
        (String alias) => alias.toLowerCase() == spoken,
      )) {
        return product;
      }
    }
    return null;
  }
}

final class _MemoryProductRepo implements ProductRepository {
  final Map<String, Product> products = <String, Product>{};

  @override
  Future<void> createProduct(Product product) async {
    products[product.id] = product;
  }

  @override
  Future<void> updateProduct(Product product) async {
    products[product.id] = product;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    products.remove(productId);
  }

  @override
  Stream<List<Product>> watchProducts() =>
      Stream<List<Product>>.value(products.values.toList());

  @override
  Future<List<Product>> getProducts() async => products.values.toList();

  @override
  Future<Product?> getProductById(String productId) async =>
      products[productId];
}

final class _MemoryStockRepo implements StockMovementRepository {
  final List<StockMovement> movements = <StockMovement>[];

  @override
  Future<void> recordMovement(StockMovement movement) async {
    movements.add(movement);
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) =>
      Stream<List<StockMovement>>.value(
        movements.where((m) => m.productId == productId).toList(),
      );
}

final class _MemorySalesRepo implements SalesRepository {
  final List<Sale> sales = <Sale>[];

  @override
  Future<Sale> recordSale(Sale sale) async {
    sales.add(sale);
    return sale;
  }

  @override
  Future<Sale> updateSale(Sale sale) async => sale;

  @override
  Future<Sale> cancelSale(String saleId) async =>
      sales.firstWhere((s) => s.id == saleId);

  @override
  Future<List<Sale>> getSalesHistory() async => sales;

  @override
  Stream<List<Sale>> watchSalesHistory() => Stream.value(sales);

  @override
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async => sales;
}

final class _MemoryDailyStatsRepo implements DailyStatsRepository {
  List<DailyStats> stats = <DailyStats>[];

  @override
  Future<List<DailyStats>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async => stats;
}

final class _FakeGenerator implements ExportGenerator {
  bool shouldThrow = false;

  @override
  Future<ExportFile> generateSalesExport({
    required List<Sale> sales,
    required List<Product> products,
    required ExportFormat format,
  }) async {
    if (shouldThrow) {
      throw Exception('Erreur génération');
    }
    return ExportFile(
      filename: 'ventes.${format.name}',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: format == ExportFormat.csv ? 'text/csv' : 'application/pdf',
    );
  }
}

final class _FakeShare implements ShareExportGateway {
  bool shouldThrow = false;
  ExportFile? sharedFile;

  @override
  Future<void> share(ExportFile file) async {
    if (shouldThrow) {
      throw Exception('Erreur partage');
    }
    sharedFile = file;
  }
}

final class _SequentialIds implements CommandIdFactory {
  int _counter = 0;

  @override
  String next() => 'cmd-${++_counter}';
}

void main() {
  final AppLocalizationsFr l10n = AppLocalizationsFr();
  late IntentCatalog catalog;
  late _MemoryProductRepo productRepo;
  late _MemoryStockRepo stockRepo;
  late _MemorySalesRepo salesRepo;
  late _MemoryDailyStatsRepo dailyStatsRepo;
  late InMemoryProductCatalog catalogReader;
  late FakeClock clock;
  late DialogManager dialog;
  late DecisionPolicy policy;
  late CommandValidator validator;
  late AnswerApplication answerApplication;

  setUp(() async {
    final String jsonContent = await File(
      'voice/intent_catalog.json',
    ).readAsString();
    catalog = parseIntentCatalog(jsonContent);
    productRepo = _MemoryProductRepo();
    stockRepo = _MemoryStockRepo();
    salesRepo = _MemorySalesRepo();
    dailyStatsRepo = _MemoryDailyStatsRepo();
    clock = FakeClock(DateTime(2026, 10, 5, 12, 0));
    dialog = DialogManager(config: const VoiceConfig(), clock: clock);
    policy = DecisionPolicy(catalog: catalog);
    validator = CommandValidator(config: const VoiceConfig(), intents: catalog);

    final List<ProductSnapshot> products = <ProductSnapshot>[
      const ProductSnapshot(
        id: 'prod-sucre',
        name: 'Sucre',
        price: 600,
        purchasePrice: 450,
        unit: 'KG',
        stock: 50,
        alertThreshold: 5,
        averageDailyQty: 2,
        aliases: <String>['sucre roux'],
      ),
      const ProductSnapshot(
        id: 'prod-lait',
        name: 'Lait Bonnet Rouge',
        price: 500,
        purchasePrice: 380,
        unit: 'BOITE',
        stock: 2,
        alertThreshold: 5,
        averageDailyQty: 1,
        aliases: <String>['lait'],
      ),
    ];
    catalogReader = InMemoryProductCatalog(products);

    answerApplication = AnswerApplication(
      intents: catalog,
      resolver: _SpokenNameResolver(products),
    );
  });

  VoiceHandlers createHandlers({
    _FakeGenerator? generator,
    _FakeShare? share,
    void Function(int, String)? navigator,
  }) {
    final RecordStockIn recordStockIn = RecordStockIn(stockRepo);
    final RecordStockOut recordStockOut = RecordStockOut(stockRepo);
    final CreateProduct createProduct = CreateProduct(productRepo);
    final UpdateProduct updateProduct = UpdateProduct(productRepo);
    final GetSalesDashboard getSalesDashboard = GetSalesDashboard(
      dailyStatsRepo,
    );
    final GetSalesHistory getSalesHistory = GetSalesHistory(salesRepo);

    return VoiceHandlers(
      recordSale: null,
      recordRestock: RealRecordRestockHandler(
        recordStockIn: recordStockIn,
        catalogReader: catalogReader,
      ),
      queryStock: null,
      queryDailyStats: RealQueryDailyStatsHandler(getSalesDashboard),
      queryLowStock: RealQueryLowStockHandler(catalogReader),
      queryProductPrice: RealQueryProductPriceHandler(catalogReader),
      recordStockOut: RealRecordStockOutHandler(
        recordStockOut: recordStockOut,
        catalogReader: catalogReader,
      ),
      navigateToPage: RealNavigateHandler(
        navigator: navigator ?? ((int idx, String dest) {}),
      ),
      exportSalesReport: RealExportReportHandler(
        exportGenerator: generator ?? _FakeGenerator(),
        shareGateway: share ?? _FakeShare(),
        getSalesHistory: getSalesHistory,
        productRepository: productRepo,
      ),
      createProduct: RealCreateProductHandler(createProduct: createProduct),
      updateProductPrice: RealUpdateProductPriceHandler(
        updateProduct: updateProduct,
        productRepository: productRepo,
        catalogReader: catalogReader,
      ),
      querySalesHistory: RealQuerySalesHistoryHandler(getSalesHistory),
      queryBusinessInfo: RealQueryBusinessInfoHandler(
        catalogReader: catalogReader,
        getSalesHistory: getSalesHistory,
      ),
    );
  }

  ExecuteCommand createExecutor(VoiceHandlers handlers) {
    final _SequentialIds ids = _SequentialIds();
    final undo = UndoLastCommand(
      handlers: handlers,
      dialog: dialog,
      clock: clock,
      ids: ids,
    );
    final List<IntentBinding> bindings = buildVoiceBindings(
      handlers: handlers,
      undo: undo,
    );
    return ExecuteCommand(
      registry: IntentRegistry(bindings),
      dialog: dialog,
      clock: clock,
      ids: ids,
    );
  }

  group('Bit-en-bit End-to-End Pipeline for 10 Online Tools', () {
    test(
      'create_product: parses, asks confirmation, creates product once confirmed and speaks recap',
      () async {
        final VoiceHandlers handlers = createHandlers();
        final ExecuteCommand executor = createExecutor(handlers);

        // 1. Cloud NLU parsing
        final parser = RemoteCloudIntentParser(
          catalogReader: catalogReader,
          cloudCaller: (String name, Map<String, dynamic> payload) async {
            return <String, dynamic>{
              'intentId': 'create_product',
              'name': 'Savon Omo',
              'price': 500,
              'purchasePrice': 350,
              'initialQty': 10,
              'unit': 'PIECE',
              'category': 'Hygiène',
            };
          },
        );

        final CommandProposal? proposal = await parser.parse(
          'ajoute le produit Savon Omo à 500',
        );
        expect(proposal, isNotNull);
        expect(proposal!.intentId, equals('create_product'));
        expect(proposal.doubts, isEmpty);

        // 2. Validation
        final doubts = validator.validate(proposal);
        expect(doubts, isEmpty);

        // 3. Policy: WRITE_SENSITIVE -> askConfirmation on the first turn
        final Decision decision = policy.decide(proposal);
        expect(decision.outcome, equals(DecisionOutcome.askConfirmation));
        expect(decision.executes, isFalse);
        dialog.ask(decision, proposal: proposal);
        expect(dialog.state, equals(VoiceDialogState.waitingForConfirmation));
        expect(dialog.pending!.slot, equals(ClarificationSlot.confirmed));

        // 4. The merchant says yes: the confirmation is recorded, not the command.
        final CommandProposal confirmed = answerApplication.apply(
          proposal,
          asked: dialog.pending!.reason,
          value: true,
        );
        expect(proposal.valueOf<bool>(kConfirmedSlot), isNull);
        expect(confirmed.valueOf<bool>(kConfirmedSlot), isTrue);

        // 5. Policy: still sensitive, but confirmed -> execute
        final Decision confirmedDecision = policy.decide(confirmed);
        expect(confirmedDecision.outcome, equals(DecisionOutcome.execute));
        expect(confirmedDecision.executes, isTrue);

        // 6. Execution
        final CommandExecution execution = await executor.run(
          decision: confirmedDecision,
          proposal: confirmed,
        );
        expect(execution.isExecuted, isTrue);
        expect(execution.failure, isNull);

        // 7. Verify product was saved in repository with ID preserved
        final Product? created = await productRepo.getProductById('prod-cmd-1');
        expect(created, isNotNull);
        expect(created!.name, equals('Savon Omo'));
        expect(created.salePrice, equals(500));
        expect(created.quantity, equals(10));

        // 8. Outcome and Spoken Text
        final VoiceOutcome? outcome = outcomeOf(execution);
        expect(outcome, isA<ProductCreated>());
        final ProductCreated productCreated = outcome! as ProductCreated;
        expect(productCreated.name, equals('Savon Omo'));
        expect(productCreated.price, equals(500.0));

        final String text = voiceMessageText(l10n, DoneMessage(productCreated));
        expect(
          text,
          contains(
            'Produit Savon Omo créé à cinq cents francs avec un stock initial de dix.',
          ),
        );

        // 9. The recap the confirmation showed named the command to authorise.
        final VoiceRecap? recap = await pendingRecapOf(
          proposal,
          (String productId) async => null,
        );
        expect(recap, isNotNull);
        expect(recap!.intentId, equals('create_product'));
        expect(
          recap.details.map((VoiceRecapDetail detail) => detail.key),
          containsAll(<String>['name', 'price', 'purchasePrice', 'initialQty']),
        );
      },
    );

    test(
      'update_product_price: parses, asks confirmation, updates price once confirmed and speaks recap',
      () async {
        // Pre-populate product in repo
        await productRepo.createProduct(
          const Product(
            id: 'prod-sucre',
            name: 'Sucre',
            category: 'Alimentation',
            unit: 'KG',
            purchasePrice: 450,
            salePrice: 600,
            quantity: 50,
            alertThreshold: 5,
          ),
        );

        final VoiceHandlers handlers = createHandlers();
        final ExecuteCommand executor = createExecutor(handlers);

        // 1. Cloud NLU parsing
        final parser = RemoteCloudIntentParser(
          catalogReader: catalogReader,
          cloudCaller: (String name, Map<String, dynamic> payload) async {
            return <String, dynamic>{
              'intentId': 'update_product_price',
              'productId': 'prod-sucre',
              'newPrice': 700.0,
            };
          },
        );

        final CommandProposal? proposal = await parser.parse(
          'change le prix du sucre à 700',
        );
        expect(proposal, isNotNull);
        expect(proposal!.intentId, equals('update_product_price'));
        expect(proposal.doubts, isEmpty);

        // 2. Policy: WRITE_SENSITIVE -> askConfirmation, so nothing changes yet
        final Decision decision = policy.decide(proposal);
        expect(decision.outcome, equals(DecisionOutcome.askConfirmation));
        expect(decision.executes, isFalse);
        dialog.ask(decision, proposal: proposal);
        expect(dialog.state, equals(VoiceDialogState.waitingForConfirmation));
        expect(
          (await productRepo.getProductById('prod-sucre'))!.salePrice,
          equals(600),
        );

        // 3. The merchant says yes, and only then does the policy run the write.
        final CommandProposal confirmed = answerApplication.apply(
          proposal,
          asked: dialog.pending!.reason,
          value: true,
        );
        final Decision confirmedDecision = policy.decide(confirmed);
        expect(confirmedDecision.outcome, equals(DecisionOutcome.execute));
        expect(confirmedDecision.executes, isTrue);

        // 4. Execution
        final CommandExecution execution = await executor.run(
          decision: confirmedDecision,
          proposal: confirmed,
        );
        expect(execution.isExecuted, isTrue);

        // 5. Verify product updated in repository
        final Product? updated = await productRepo.getProductById('prod-sucre');
        expect(updated!.salePrice, equals(700));

        // 6. Outcome and Spoken Text
        final VoiceOutcome? outcome = outcomeOf(execution);
        expect(outcome, isA<ProductPriceUpdated>());
        final ProductPriceUpdated priceUpdated =
            outcome! as ProductPriceUpdated;
        expect(priceUpdated.newPrice, equals(700.0));
        expect(priceUpdated.oldPrice, equals(600.0));

        final String text = voiceMessageText(l10n, DoneMessage(priceUpdated));
        expect(
          text,
          contains(
            'Le prix de Sucre a été mis à jour à sept cents francs (ancien prix : six cents francs).',
          ),
        );

        // 7. The recap named the product and the figure, read from the catalog
        //    because the proposal only carries its identifier.
        final VoiceRecap? recap = await pendingRecapOf(
          proposal,
          (String productId) async => productId == 'prod-sucre'
              ? (await catalogReader.findById('prod-sucre'))
              : null,
        );
        expect(recap!.lines.map((VoiceRecapLine line) => line.name), <String>[
          'Sucre',
        ]);
        expect(
          recap.details
              .firstWhere((VoiceRecapDetail d) => d.key == 'newPrice')
              .amount,
          equals(700.0),
        );
      },
    );

    test(
      'record_stock_out: handles fractional quantity (0.5 kg) without zero-truncation failure',
      () async {
        final VoiceHandlers handlers = createHandlers();
        final ExecuteCommand executor = createExecutor(handlers);

        final parser = RemoteCloudIntentParser(
          catalogReader: catalogReader,
          cloudCaller: (String name, Map<String, dynamic> payload) async {
            return <String, dynamic>{
              'intentId': 'record_stock_out',
              'productId': 'prod-sucre',
              'qty': 0.5,
              'reason': 'perte',
            };
          },
        );

        final CommandProposal? proposal = await parser.parse(
          'perte de 0.5 kg de sucre',
        );
        expect(proposal, isNotNull);
        final Decision decision = policy.decide(proposal!);
        expect(decision.executes, isTrue);

        final CommandExecution execution = await executor.run(
          decision: decision,
          proposal: proposal,
        );
        expect(execution.isExecuted, isTrue);
        expect(execution.failure, isNull);

        // Verify stock movement recorded with at least 1 unit
        expect(stockRepo.movements, isNotEmpty);
        expect(stockRepo.movements.first.quantity, equals(1));

        final VoiceOutcome? outcome = outcomeOf(execution);
        expect(outcome, isA<StockOutRecorded>());
        final String text = voiceMessageText(l10n, DoneMessage(outcome!));
        expect(text, contains('Sortie de 0,5 Sucre (perte) enregistrée.'));
      },
    );

    test(
      'record_restock: handles fractional quantity without zero-truncation failure',
      () async {
        final VoiceHandlers handlers = createHandlers();
        final ExecuteCommand executor = createExecutor(handlers);

        final parser = RemoteCloudIntentParser(
          catalogReader: catalogReader,
          cloudCaller: (String name, Map<String, dynamic> payload) async {
            return <String, dynamic>{
              'intentId': 'record_restock',
              'items': [
                {
                  'productId': 'prod-sucre',
                  'qty': 0.75,
                  'spokenUnitCost': 400.0,
                },
              ],
            };
          },
        );

        final CommandProposal? proposal = await parser.parse(
          'reçu 0.75 kg de sucre',
        );
        expect(proposal, isNotNull);
        final Decision decision = policy.decide(proposal!);
        expect(decision.executes, isTrue);

        final CommandExecution execution = await executor.run(
          decision: decision,
          proposal: proposal,
        );
        expect(execution.isExecuted, isTrue);
        expect(execution.failure, isNull);

        // Movement recorded with ceil/round >= 1
        expect(stockRepo.movements.last.quantity, equals(1));
      },
    );

    test(
      'navigate_to_page: correctly resolves all destination synonyms',
      () async {
        int navigatedTab = -1;
        String navigatedDest = '';

        final VoiceHandlers handlers = createHandlers(
          navigator: (int tab, String dest) {
            navigatedTab = tab;
            navigatedDest = dest;
          },
        );
        final ExecuteCommand executor = createExecutor(handlers);

        final destinationsToExpectedTabs = <String, int>{
          'caisse': 0,
          'panier': 0,
          'accueil': 0,
          'dashboard': 0,
          'mon stock': 1,
          'inventaire': 1,
          'catalogue': 1,
          'produit': 1,
          'historique des ventes': 2,
          'rapport': 2,
          'export': 2,
          'bilan': 2,
          'profil': 3,
          'parametre': 3,
          'compte': 3,
          'reglage': 3,
          'configuration': 3,
        };

        for (final entry in destinationsToExpectedTabs.entries) {
          final parser = RemoteCloudIntentParser(
            catalogReader: catalogReader,
            cloudCaller: (name, payload) async => <String, dynamic>{
              'intentId': 'navigate_to_page',
              'destination': entry.key,
            },
          );
          final proposal = await parser.parse('ouvre ${entry.key}');
          final decision = policy.decide(proposal!);
          await executor.run(decision: decision, proposal: proposal);

          expect(
            navigatedTab,
            equals(entry.value),
            reason: 'Failed for destination: ${entry.key}',
          );
          expect(navigatedDest, equals(entry.key));
        }
      },
    );

    test(
      'export_sales_report: catches exceptions and returns ExportFailed safely',
      () async {
        final fakeGenerator = _FakeGenerator()..shouldThrow = true;
        final VoiceHandlers handlers = createHandlers(generator: fakeGenerator);
        final ExecuteCommand executor = createExecutor(handlers);

        final parser = RemoteCloudIntentParser(
          catalogReader: catalogReader,
          cloudCaller: (name, payload) async => <String, dynamic>{
            'intentId': 'export_sales_report',
            'format': 'pdf',
          },
        );
        final proposal = await parser.parse('exporte les ventes en PDF');
        final decision = policy.decide(proposal!);
        final CommandExecution execution = await executor.run(
          decision: decision,
          proposal: proposal,
        );

        expect(execution.isExecuted, isTrue);
        expect(execution.failure, isA<ExportFailed>());
      },
    );

    test('query_daily_stats: end to end execution and spoken recap', () async {
      dailyStatsRepo.stats = <DailyStats>[
        DailyStats(
          salesCount: 5,
          revenue: 12500,
          cost: 9000,
          qtyByProduct: {'prod-sucre': 5},
        ),
      ];

      final VoiceHandlers handlers = createHandlers();
      final ExecuteCommand executor = createExecutor(handlers);

      final parser = RemoteCloudIntentParser(
        catalogReader: catalogReader,
        cloudCaller: (name, payload) async => <String, dynamic>{
          'intentId': 'query_daily_stats',
          'date': 'today',
        },
      );
      final proposal = await parser.parse('bilan du jour');
      final decision = policy.decide(proposal!);
      final CommandExecution execution = await executor.run(
        decision: decision,
        proposal: proposal,
      );

      expect(execution.isExecuted, isTrue);
      final VoiceOutcome? outcome = outcomeOf(execution);
      expect(outcome, isA<DailyStatsRead>());

      final String text = voiceMessageText(l10n, DoneMessage(outcome!));
      expect(text, contains("Aujourd'hui : 5 ventes"));
      expect(text, contains('total douze mille cinq cents francs'));
      expect(text, contains('bénéfice trois mille cinq cents francs'));
    });

    test('query_low_stock: reports products below stock threshold', () async {
      final VoiceHandlers handlers = createHandlers();
      final ExecuteCommand executor = createExecutor(handlers);

      final parser = RemoteCloudIntentParser(
        catalogReader: catalogReader,
        cloudCaller: (name, payload) async => <String, dynamic>{
          'intentId': 'query_low_stock',
        },
      );
      final proposal = await parser.parse('quels sont les produits en rupture');
      final decision = policy.decide(proposal!);
      final CommandExecution execution = await executor.run(
        decision: decision,
        proposal: proposal,
      );

      expect(execution.isExecuted, isTrue);
      final VoiceOutcome? outcome = outcomeOf(execution);
      expect(outcome, isA<LowStockRead>());
      final LowStockRead lowStock = outcome! as LowStockRead;
      expect(
        lowStock.products.length,
        equals(1),
      ); // Lait Bonnet Rouge has stock 2 <= 5
      expect(lowStock.products.first.name, equals('Lait Bonnet Rouge'));

      final String text = voiceMessageText(l10n, DoneMessage(lowStock));
      expect(
        text,
        contains(
          '1 produit en alerte de stock : Lait Bonnet Rouge (reste deux)',
        ),
      );
    });

    test('query_product_price: reads price and purchase price', () async {
      final VoiceHandlers handlers = createHandlers();
      final ExecuteCommand executor = createExecutor(handlers);

      final parser = RemoteCloudIntentParser(
        catalogReader: catalogReader,
        cloudCaller: (name, payload) async => <String, dynamic>{
          'intentId': 'query_product_price',
          'productId': 'prod-sucre',
        },
      );
      final proposal = await parser.parse('quel est le prix du sucre');
      final decision = policy.decide(proposal!);
      final CommandExecution execution = await executor.run(
        decision: decision,
        proposal: proposal,
      );

      expect(execution.isExecuted, isTrue);
      final VoiceOutcome? outcome = outcomeOf(execution);
      expect(outcome, isA<ProductPriceRead>());

      final String text = voiceMessageText(l10n, DoneMessage(outcome!));
      expect(text, contains('Le prix de Sucre est de six cents francs'));
      expect(text, contains("prix d'achat : quatre cent cinquante francs"));
    });

    test('query_business_info: computes store summary', () async {
      salesRepo.sales.add(
        Sale(
          id: 'sale-1',
          dateTime: DateTime(2026, 10, 5, 10, 0),
          createdAt: DateTime(2026, 10, 5, 10, 0),
          total: 1000,
          items: const [],
          source: 'voice',
          status: 'completed',
        ),
      );

      final VoiceHandlers handlers = createHandlers();
      final ExecuteCommand executor = createExecutor(handlers);

      final parser = RemoteCloudIntentParser(
        catalogReader: catalogReader,
        cloudCaller: (name, payload) async => <String, dynamic>{
          'intentId': 'query_business_info',
        },
      );
      final proposal = await parser.parse('info boutique');
      final decision = policy.decide(proposal!);
      final CommandExecution execution = await executor.run(
        decision: decision,
        proposal: proposal,
      );

      expect(execution.isExecuted, isTrue);
      final VoiceOutcome? outcome = outcomeOf(execution);
      expect(outcome, isA<BusinessInfoRead>());

      final String text = voiceMessageText(l10n, DoneMessage(outcome!));
      expect(text, contains('KioskMind : 2 produits actifs'));
      expect(text, contains('1 vente enregistrées'));
    });
  });

  group('DialogManager hardening', () {
    test(
      'DialogManager.ask handles askConfirmation with null reason without dropping',
      () {
        final proposal = CommandProposal(
          intentId: 'create_product',
          slots: const [],
          doubts: const [],
          origin: ProposalOrigin.languageModel,
        );

        // Decision with askConfirmation and null reason
        const decision = Decision(DecisionOutcome.askConfirmation);
        dialog.ask(decision, proposal: proposal);

        expect(dialog.pending, isNotNull);
        expect(dialog.pending!.slot, equals(ClarificationSlot.confirmed));
        expect(dialog.pending!.reason, equals(DoubtKind.amountMismatch));
      },
    );
  });
}
