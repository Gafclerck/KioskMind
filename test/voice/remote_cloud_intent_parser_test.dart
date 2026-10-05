import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/remote_cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';

ProductSnapshot _makeProduct(
  String id, {
  required String name,
  double price = 500,
  double? purchasePrice = 400,
  double stock = 10,
  String unit = 'PIECE',
  bool isArchived = false,
}) {
  return ProductSnapshot(
    id: id,
    name: name,
    aliases: const <String>[],
    unit: unit,
    price: price,
    purchasePrice: purchasePrice,
    stock: stock,
    alertThreshold: 2,
    averageDailyQty: 1,
    isArchived: isArchived,
  );
}

void main() {
  late InMemoryProductCatalog catalog;

  setUp(() {
    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      _makeProduct('p_sucre', name: 'Sucre roux', price: 750, stock: 15),
      _makeProduct('p_riz', name: 'Riz 5kg', price: 4500, stock: 8),
      _makeProduct('p_archived', name: 'Archive', price: 100, isArchived: true),
    ]);
  });

  group('RemoteCloudIntentParser', () {
    test('transmits utterance and catalog payload to cloud caller', () async {
      String? calledFunction;
      Map<String, dynamic>? receivedPayload;

      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async {
          calledFunction = functionName;
          receivedPayload = parameters;
          return <String, dynamic>{
            'intentId': 'query_stock',
            'productId': 'p_sucre',
          };
        },
      );

      final proposal = await parser.parse('combien de sucre reste-t-il');

      expect(calledFunction, equals('interpretUtterance'));
      expect(
        receivedPayload?['utterance'],
        equals('combien de sucre reste-t-il'),
      );
      final catalogList = receivedPayload?['catalog'] as List<dynamic>?;
      expect(catalogList?.length, equals(2)); // Only active products
      expect(proposal, isNotNull);
      expect(proposal!.origin, equals(ProposalOrigin.languageModel));
      expect(proposal.intentId, equals('query_stock'));
      expect(proposal.valueOf<String>(kProductIdSlot), equals('p_sucre'));
    });

    test('parses record_sale with valid products and quantities', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'record_sale',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 'p_sucre',
              'qty': 2.0,
              'spokenUnitPrice': 750.0,
            },
          ],
        },
      );

      final proposal = await parser.parse('vendu deux sucres');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('record_sale'));
      expect(proposal.origin, equals(ProposalOrigin.languageModel));
      expect(proposal.doubts, isEmpty);

      final items = proposal.valueOf<List<ItemMention>>(kItemsSlot);
      expect(items, isNotNull);
      expect(items!.length, equals(1));
      expect(items.first.product.id, equals('p_sucre'));
      expect(items.first.qty, equals(2.0));
      expect(items.first.spokenAmount, equals(750.0));
    });

    test(
      'adds unknownProduct doubt when cloud model returns unknown productId (D5)',
      () async {
        final parser = RemoteCloudIntentParser(
          catalogReader: catalog,
          cloudCaller: (functionName, parameters) async => <String, dynamic>{
            'intentId': 'record_sale',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'productId': 'invented_by_llm', 'qty': 1.0},
            ],
          },
        );

        final proposal = await parser.parse('vends un produit bizarre');

        expect(proposal, isNotNull);
        expect(proposal!.hasDoubt(DoubtKind.unknownProduct), isTrue);
      },
    );

    test('parses record_restock with cost and quantity', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'record_restock',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 'p_riz',
              'qty': 5.0,
              'spokenUnitCost': 4000.0,
            },
          ],
        },
      );

      final proposal = await parser.parse('arrivage de 5 riz a 4000');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('record_restock'));
      final items = proposal.valueOf<List<ItemMention>>(kItemsSlot);
      expect(items?.first.product.id, equals('p_riz'));
      expect(items?.first.qty, equals(5.0));
      expect(items?.first.spokenAmount, equals(4000.0));
    });

    test('parses cancel_last_sale intent with empty slots', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'cancel_last_sale',
        },
      );

      final proposal = await parser.parse('annule la vente');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('cancel_last_sale'));
      expect(proposal.slots, isEmpty);
      expect(proposal.doubts, isEmpty);
    });

    test('returns null when cloud caller throws exception', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async {
          throw Exception('Firebase Cloud Function internal error');
        },
      );

      final proposal = await parser.parse('vendu du sucre');

      expect(proposal, isNull);
    });

    test('returns null when intentId is unknown or unsupported', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'unsupported_weather_intent',
        },
      );

      final proposal = await parser.parse('quel temps fait-il');

      expect(proposal, isNull);
    });

    test('parses query_daily_stats with optional date', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_daily_stats',
          'date': '2026-03-01',
        },
      );

      final proposal = await parser.parse('combien j\'ai vendu aujourd\'hui');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('query_daily_stats'));
      expect(proposal.valueOf<String>('date'), equals('2026-03-01'));
      expect(proposal.origin, equals(ProposalOrigin.languageModel));
    });

    test('parses query_low_stock with optional threshold', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_low_stock',
          'level': 'rupture',
        },
      );

      final proposal = await parser.parse('quels produits sont en rupture');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('query_low_stock'));
      expect(proposal.valueOf<String>('level'), equals('rupture'));
    });

    test('parses query_product_price with valid product', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_product_price',
          'productId': 'p_sucre',
        },
      );

      final proposal = await parser.parse('quel est le prix du sucre');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('query_product_price'));
      expect(proposal.valueOf<String>(kProductIdSlot), equals('p_sucre'));
    });

    test('parses record_stock_out with qty and reason', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'record_stock_out',
          'productId': 'p_sucre',
          'qty': 3.0,
          'reason': 'perte',
        },
      );

      final proposal = await parser.parse('retire 3 sucres avaries');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('record_stock_out'));
      expect(proposal.valueOf<String>(kProductIdSlot), equals('p_sucre'));
      expect(proposal.valueOf<double>('qty'), equals(3.0));
      expect(proposal.valueOf<String>('reason'), equals('perte'));
    });

    test('parses navigate_to_page with destination', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'navigate_to_page',
          'destination': 'sales',
        },
      );

      final proposal = await parser.parse('va aux ventes');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('navigate_to_page'));
      expect(proposal.valueOf<String>('destination'), equals('sales'));
    });

    test('parses export_sales_report with format', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'export_sales_report',
          'format': 'pdf',
        },
      );

      final proposal = await parser.parse('exporte le rapport en pdf');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('export_sales_report'));
      expect(proposal.valueOf<String>('format'), equals('pdf'));
    });

    test('parses create_product with name, price and stock', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'create_product',
          'name': 'Biscuit',
          'price': 250.0,
          'purchasePrice': 200.0,
          'initialQuantity': 20.0,
          'unit': 'PIECE',
        },
      );

      final proposal = await parser.parse('cree le produit biscuit a 250');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('create_product'));
      expect(proposal.valueOf<String>('name'), equals('Biscuit'));
      expect(proposal.valueOf<double>('price'), equals(250.0));
      expect(proposal.valueOf<double>('purchasePrice'), equals(200.0));
      expect(proposal.valueOf<double>('initialQty'), equals(20.0));
      expect(proposal.valueOf<String>('unit'), equals('PIECE'));
    });

    test('parses update_product_price with new price', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'update_product_price',
          'productId': 'p_sucre',
          'newPrice': 800.0,
        },
      );

      final proposal = await parser.parse('change le prix du sucre a 800');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('update_product_price'));
      expect(proposal.valueOf<String>(kProductIdSlot), equals('p_sucre'));
      expect(proposal.valueOf<double>('newPrice'), equals(800.0));
    });

    test('parses query_sales_history with limit', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_sales_history',
          'limit': 5,
        },
      );

      final proposal = await parser.parse('montre les dernieres ventes');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('query_sales_history'));
      expect(proposal.valueOf<int>('limit'), equals(5));
    });

    test('parses query_business_info with empty slots', () async {
      final parser = RemoteCloudIntentParser(
        catalogReader: catalog,
        cloudCaller: (functionName, parameters) async => <String, dynamic>{
          'intentId': 'query_business_info',
        },
      );

      final proposal = await parser.parse('info boutique');

      expect(proposal, isNotNull);
      expect(proposal!.intentId, equals('query_business_info'));
    });
  });
}
