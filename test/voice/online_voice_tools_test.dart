import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/localization/generated/app_localizations_fr.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
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
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_create_product_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_navigate_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_business_info_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_daily_stats_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_low_stock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_product_price_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_query_sales_history_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_record_stock_out_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_update_product_price_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'rule_parser_harness.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_definition.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_message.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/widgets/voice_message_text.dart';

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
  Future<List<Sale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async => sales;
}

final class _MemoryDailyStatsRepo implements DailyStatsRepository {
  _MemoryDailyStatsRepo(this.stats);

  final List<DailyStats> stats;

  @override
  Future<List<DailyStats>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async => stats;
}

void main() {
  final String shippedCatalogJson = File(intentCatalogAsset).readAsStringSync();
  late IntentCatalog catalog;
  late InMemoryProductCatalog productCatalog;

  setUp(() {
    catalog = parseIntentCatalog(shippedCatalogJson);
    productCatalog = InMemoryProductCatalog(<ProductSnapshot>[
      ProductSnapshot(
        id: 'p_sucre',
        name: 'Sucre en poudre',
        aliases: const <String>['sucre'],
        unit: 'KG',
        price: 800,
        purchasePrice: 650,
        stock: 2,
        alertThreshold: 5,
        averageDailyQty: 1,
        isArchived: false,
      ),
      ProductSnapshot(
        id: 'p_riz',
        name: 'Riz brisure',
        aliases: const <String>['riz'],
        unit: 'SAC',
        price: 15000,
        purchasePrice: 13000,
        stock: 20,
        alertThreshold: 5,
        averageDailyQty: 2,
        isArchived: false,
      ),
    ]);
  });

  group('Intent Catalog Partitioning & Online-Only Constraints', () {
    test('contains 14 supported intents in total', () {
      expect(catalog.intents.length, 14);
      expect(catalog.ids.toSet(), kSupportedIntentIds);
    });

    test('strictly partitions offline (4) and online-only (10) intents', () {
      expect(
        catalog.offlineIntents.map((IntentDefinition i) => i.id).toSet(),
        kCoreOfflineIntentIds,
      );
      expect(
        catalog.onlineOnlyIntents.map((IntentDefinition i) => i.id).toSet(),
        kOnlineOnlyIntentIds,
      );

      for (final IntentDefinition intent in catalog.offlineIntents) {
        expect(
          intent.onlineOnly,
          isFalse,
          reason: '${intent.id} must be offline',
        );
      }

      for (final IntentDefinition intent in catalog.onlineOnlyIntents) {
        expect(
          intent.onlineOnly,
          isTrue,
          reason: '${intent.id} must be online-only',
        );
      }
    });

    test('RuleBasedParser strictly never triggers online-only intents', () async {
      final RuleBasedParser offlineParser = RuleParserHarness().parser;

      final List<String> onlineUtterances = <String>[
        'combien j ai vendu aujourd hui',
        'chiffre d affaires du jour',
        'quels sont les produits en rupture',
        'alerte stock',
        'quel est le prix du sucre',
        'retire deux sacs de riz avaries',
        'va a l ecran des ventes',
        'exporte les ventes en pdf',
        'cree un nouveau produit cafe a 500',
        'augmente le prix du sucre a 900',
        'historique des dernieres ventes',
        'informations sur la boutique',
      ];

      for (final String utterance in onlineUtterances) {
        final CommandProposal proposal = offlineParser.parse(utterance);
        expect(
          kOnlineOnlyIntentIds.contains(proposal.intentId),
          isFalse,
          reason:
              'RuleBasedParser returned online intent ${proposal.intentId} for "$utterance"',
        );
      }
    });
  });

  group('Real Online Handlers', () {
    final CommandContext context = (
      commandId: 'cmd-test-1',
      dateTime: DateTime(2026, 3, 1, 10, 30),
      source: CommandSource.voice,
    );

    test('RealQueryDailyStatsHandler aggregates dashboard data', () async {
      final GetSalesDashboard dashboard = GetSalesDashboard(
        _MemoryDailyStatsRepo(<DailyStats>[
          DailyStats(
            revenue: 15000,
            cost: 10500,
            salesCount: 6,
            qtyByProduct: const <String, double>{'p_sucre': 12},
          ),
        ]),
      );

      final RealQueryDailyStatsHandler handler = RealQueryDailyStatsHandler(
        dashboard,
      );
      final Result<QueryDailyStatsResult> result = await handler.execute(
        context,
        const QueryDailyStatsInput(date: '2026-03-01'),
      );

      expect(result, isA<Success<QueryDailyStatsResult>>());
      final QueryDailyStatsResult stats =
          (result as Success<QueryDailyStatsResult>).value;
      expect(stats.salesCount, 6);
      expect(stats.totalRevenue, 15000);
      expect(stats.totalProfit, 4500);
      expect(stats.itemsSold, 12);
    });

    test(
      'RealQueryLowStockHandler identifies products under threshold',
      () async {
        final RealQueryLowStockHandler handler = RealQueryLowStockHandler(
          productCatalog,
        );
        final Result<QueryLowStockResult> result = await handler.execute(
          context,
          const QueryLowStockInput(),
        );

        expect(result, isA<Success<QueryLowStockResult>>());
        final QueryLowStockResult low =
            (result as Success<QueryLowStockResult>).value;
        // p_sucre has stock 2 with alertThreshold 5 => low stock
        expect(low.products.length, 1);
        expect(low.products.first.productId, 'p_sucre');
        expect(low.products.first.stock, 2);
      },
    );

    test(
      'RealQueryProductPriceHandler finds selling and purchase price',
      () async {
        final RealQueryProductPriceHandler handler =
            RealQueryProductPriceHandler(productCatalog);
        final Result<QueryProductPriceResult> result = await handler.execute(
          context,
          const QueryProductPriceInput(productId: 'p_sucre'),
        );

        expect(result, isA<Success<QueryProductPriceResult>>());
        final QueryProductPriceResult price =
            (result as Success<QueryProductPriceResult>).value;
        expect(price.productId, 'p_sucre');
        expect(price.price, 800);
        expect(price.purchasePrice, 650);
        expect(price.unit, 'KG');
      },
    );

    test(
      'RealRecordStockOutHandler writes movement and returns new stock',
      () async {
        final _MemoryStockRepo stockRepo = _MemoryStockRepo();
        final RealRecordStockOutHandler handler = RealRecordStockOutHandler(
          recordStockOut: RecordStockOut(stockRepo),
          catalogReader: productCatalog,
        );

        final Result<RecordStockOutResult> result = await handler.execute(
          context,
          const RecordStockOutInput(
            productId: 'p_riz',
            qty: 3,
            reason: 'perte',
          ),
        );

        expect(result, isA<Success<RecordStockOutResult>>());
        final RecordStockOutResult out =
            (result as Success<RecordStockOutResult>).value;
        expect(out.productId, 'p_riz');
        expect(out.qty, 3);
        expect(out.reason, 'perte');
        expect(out.resultingStock, 17); // 20 - 3
        expect(stockRepo.movements.length, 1);
        expect(stockRepo.movements.first.quantity, 3);
        expect(stockRepo.movements.first.type, StockMovementType.manualOut);
      },
    );

    test('RealNavigateHandler maps destination names to tab index', () async {
      int? navigatedTab;
      final RealNavigateHandler handler = RealNavigateHandler(
        navigator: (int tabIndex, String destination) {
          navigatedTab = tabIndex;
        },
      );

      final Result<NavigateToPageResult> result = await handler.execute(
        context,
        const NavigateToPageInput(destination: 'sales'),
      );

      expect(result, isA<Success<NavigateToPageResult>>());
      expect(navigatedTab, 0); // Ventes tab index
      final NavigateToPageResult nav =
          (result as Success<NavigateToPageResult>).value;
      expect(nav.label, 'Accueil');
    });

    test('RealCreateProductHandler saves product to repository', () async {
      final _MemoryProductRepo productRepo = _MemoryProductRepo();

      final RealCreateProductHandler handler = RealCreateProductHandler(
        createProduct: CreateProduct(productRepo),
      );

      final Result<CreateProductResult> result = await handler.execute(
        context,
        const CreateProductInput(
          name: 'Savon liquide',
          price: 1200,
          purchasePrice: 900,
          initialQty: 10,
          unit: 'PIECE',
        ),
      );

      expect(result, isA<Success<CreateProductResult>>());
      final CreateProductResult created =
          (result as Success<CreateProductResult>).value;
      expect(created.name, 'Savon liquide');
      expect(created.price, 1200);
      expect(created.initialQuantity, 10);
      expect(productRepo.products.values.length, 1);
    });

    test('RealUpdateProductPriceHandler updates price in repository', () async {
      final _MemoryProductRepo productRepo = _MemoryProductRepo();
      await productRepo.createProduct(
        const Product(
          id: 'p_sucre',
          name: 'Sucre en poudre',
          category: 'Alimentation',
          unit: 'KG',
          salePrice: 800,
          purchasePrice: 650,
          quantity: 2,
          alertThreshold: 5,
        ),
      );

      final RealUpdateProductPriceHandler handler =
          RealUpdateProductPriceHandler(
            updateProduct: UpdateProduct(productRepo),
            productRepository: productRepo,
            catalogReader: productCatalog,
          );

      final Result<UpdateProductPriceResult> result = await handler.execute(
        context,
        const UpdateProductPriceInput(productId: 'p_sucre', newPrice: 950),
      );

      expect(result, isA<Success<UpdateProductPriceResult>>());
      final UpdateProductPriceResult updated =
          (result as Success<UpdateProductPriceResult>).value;
      expect(updated.productId, 'p_sucre');
      expect(updated.oldPrice, 800);
      expect(updated.newPrice, 950);
      expect(productRepo.products['p_sucre']?.salePrice, 950);
    });

    test('RealQuerySalesHistoryHandler returns sales from history', () async {
      final _MemorySalesRepo salesRepo = _MemorySalesRepo();
      salesRepo.sales.add(
        Sale(
          id: 'sale-1',
          dateTime: DateTime(2026, 3, 1, 9),
          createdAt: DateTime(2026, 3, 1, 9),
          total: 3500,
          items: <SaleItem>[
            SaleItem(
              productId: 'p_sucre',
              name: 'Sucre',
              qty: 2,
              unitPrice: 800,
            ),
          ],
          source: 'VOICE',
          status: 'COMPLETED',
        ),
      );

      final RealQuerySalesHistoryHandler handler = RealQuerySalesHistoryHandler(
        GetSalesHistory(salesRepo),
      );

      final Result<QuerySalesHistoryResult> result = await handler.execute(
        context,
        const QuerySalesHistoryInput(limit: 5),
      );

      expect(result, isA<Success<QuerySalesHistoryResult>>());
      final QuerySalesHistoryResult hist =
          (result as Success<QuerySalesHistoryResult>).value;
      expect(hist.sales.length, 1);
      expect(hist.sales.first.total, 3500);
    });

    test('RealQueryBusinessInfoHandler returns store overview', () async {
      final _MemorySalesRepo salesRepo = _MemorySalesRepo();
      salesRepo.sales.add(
        Sale(
          id: 's-1',
          dateTime: DateTime(2026, 3, 1),
          createdAt: DateTime(2026, 3, 1),
          total: 1000,
          items: const <SaleItem>[],
          source: 'VOICE',
          status: 'COMPLETED',
        ),
      );

      final RealQueryBusinessInfoHandler handler = RealQueryBusinessInfoHandler(
        catalogReader: productCatalog,
        getSalesHistory: GetSalesHistory(salesRepo),
      );

      final Result<QueryBusinessInfoResult> result = await handler.execute(
        context,
        const QueryBusinessInfoInput(),
      );

      expect(result, isA<Success<QueryBusinessInfoResult>>());
      final QueryBusinessInfoResult info =
          (result as Success<QueryBusinessInfoResult>).value;
      expect(info.storeName, 'KioskMind');
      expect(info.activeProductsCount, 2);
      expect(info.totalSalesCount, 1);
    });
  });

  group('VoiceMessageText Formatter for Online Outcomes', () {
    final AppLocalizationsFr l10n = AppLocalizationsFr();

    test('formats DailyStatsRead', () {
      const DailyStatsRead outcome = DailyStatsRead(
        salesCount: 5,
        totalRevenue: 25000,
        totalProfit: 6000,
        itemsSold: 10,
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, contains("Aujourd'hui : 5 ventes"));
      expect(text, contains('total'));
      expect(text, contains('francs'));
      expect(text, contains('bénéfice'));
    });

    test('formats LowStockRead with items and when empty', () {
      final LowStockRead outcomeWithItems = LowStockRead(<LowStockItemResult>[
        (
          productId: 'p_sucre',
          name: 'Sucre',
          stock: 1,
          unit: 'KG',
          alertThreshold: 5,
          alertLevel: 'rupture',
        ),
      ]);
      final String textWithItems = voiceMessageText(
        l10n,
        DoneMessage(outcomeWithItems),
      );
      expect(textWithItems, contains('1 produit en alerte de stock'));
      expect(textWithItems, contains('Sucre (reste un'));

      const LowStockRead emptyOutcome = LowStockRead(<LowStockItemResult>[]);
      final String emptyText = voiceMessageText(
        l10n,
        const DoneMessage(emptyOutcome),
      );
      expect(emptyText, 'Aucun produit en rupture ou stock bas.');
    });

    test('formats ProductPriceRead', () {
      const ProductPriceRead outcome = ProductPriceRead(
        product: 'Sucre',
        price: 800,
        purchasePrice: 650,
        unit: 'KG',
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, contains('Le prix de Sucre est de'));
      expect(text, contains('prix d\'achat'));
    });

    test('formats StockOutRecorded', () {
      const StockOutRecorded outcome = StockOutRecorded(
        product: 'Riz',
        qty: 3,
        reason: 'perte',
        resultingStock: 17,
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, contains('Sortie de'));
      expect(text, contains('Riz (perte) enregistrée'));
      expect(text, contains('Stock restant'));
    });

    test('formats PageNavigated', () {
      const PageNavigated outcome = PageNavigated('Ventes');
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, 'Navigation vers Ventes.');
    });

    test('formats ReportExported', () {
      const ReportExported outcome = ReportExported(
        format: 'pdf',
        salesCount: 15,
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(
        text,
        contains(
          'Rapport des ventes (15 ventes) généré et partagé au format PDF.',
        ),
      );
    });

    test('formats ProductCreated', () {
      const ProductCreated outcome = ProductCreated(
        name: 'Savon',
        price: 500,
        initialQuantity: 10,
        unit: 'PIECE',
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, contains('Produit Savon créé à'));
      expect(text, contains('stock initial de'));
    });

    test('formats ProductPriceUpdated', () {
      const ProductPriceUpdated outcome = ProductPriceUpdated(
        product: 'Sucre',
        oldPrice: 800,
        newPrice: 950,
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, contains('Le prix de Sucre a été mis à jour à'));
      expect(text, contains('ancien prix'));
    });

    test('formats SalesHistoryRead', () {
      final SalesHistoryRead outcome = SalesHistoryRead(<SaleHistoryItemResult>[
        (
          saleId: 's-1',
          dateTime: DateTime(2026, 3, 1),
          total: 2500,
          itemsCount: 3,
        ),
      ]);
      final String text = voiceMessageText(l10n, DoneMessage(outcome));
      expect(text, contains('Dernière vente'));
      expect(text, contains('3 articles pour'));
    });

    test('formats BusinessInfoRead', () {
      const BusinessInfoRead outcome = BusinessInfoRead(
        storeName: 'Kiosk Mind',
        activeProductsCount: 12,
        totalSalesCount: 45,
      );
      final String text = voiceMessageText(l10n, const DoneMessage(outcome));
      expect(text, 'Kiosk Mind : 12 produits actifs, 45 ventes enregistrées.');
    });
  });
}
