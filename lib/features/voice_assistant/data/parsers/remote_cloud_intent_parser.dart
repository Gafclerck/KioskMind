import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/doubt.dart';
import '../../domain/entities/parse_route.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/entities/slot.dart';
import '../../domain/ports/cloud_intent_parser.dart';
import '../../domain/ports/intent_handler.dart';
import '../../domain/ports/parse_outcome_journal.dart';
import '../../domain/ports/product_catalog_reader.dart';
import 'cloud_call_failure.dart';

typedef CloudFunctionCaller =
    Future<Map<String, dynamic>> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );

/// Adapter implementing [CloudIntentParser] that sends an utterance and the
/// current active catalog snapshot to a remote cloud function for LLM tool selection.
///
/// Grounding guarantee (D5): all products returned by the remote language model
/// are strictly cross-referenced against [catalogReader]. If the remote model names
/// an unknown product id, it is treated as a doubt rather than executed.
///
/// Every way this parser can fail to produce a proposal is written to [journal]
/// before the null that stands for it is returned. Returning null is what tells the
/// cascade to fall back to the rules parser, and it used to be the only thing that
/// happened, which made an absent credential, a refused key and a model that answered
/// with nothing at all look identical from outside.
final class RemoteCloudIntentParser implements CloudIntentParser {
  RemoteCloudIntentParser({
    required this.catalogReader,
    CloudFunctionCaller? cloudCaller,
    this.journal,
  }) : _cloudCaller = cloudCaller ?? _defaultFirebaseCaller;

  final ProductCatalogReader catalogReader;
  final CloudFunctionCaller _cloudCaller;

  /// Optional, for the same reason the cascade's is: a test drives this parser
  /// without caring what the route was.
  final ParseOutcomeJournal? journal;

  static Future<Map<String, dynamic>> _defaultFirebaseCaller(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      functionName,
    );
    final HttpsCallableResult<dynamic> result = await callable.call<dynamic>(
      parameters,
    );
    final dynamic data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  @override
  Future<CommandProposal?> parse(String raw) async {
    // Set once the gateway has actually answered, so the catch below can tell a call
    // that failed from an answer that could not be read. They are different defects
    // and the merchant cannot tell them apart either way.
    bool answered = false;
    try {
      final List<ProductSnapshot> activeProducts = await catalogReader
          .readActiveProducts();

      final Map<String, dynamic> payload = <String, dynamic>{
        'utterance': raw,
        'catalog': <Map<String, dynamic>>[
          for (final ProductSnapshot p in activeProducts)
            <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'unit': p.unit,
              'price': p.price,
              if (p.purchasePrice != null) 'purchasePrice': p.purchasePrice,
              'aliases': p.aliases,
            },
        ],
      };

      final Map<String, dynamic> response = await _cloudCaller(
        'interpretUtterance',
        payload,
      );
      answered = true;

      final String? intentId = response['intentId'] as String?;
      if (intentId == null || intentId.isEmpty) {
        journal?.record(
          ParseRouteEvent(
            utterance: raw,
            reason: ParseRouteReason.noIntentReturned,
          ),
        );
        return null;
      }
      if (!kSupportedIntentIds.contains(intentId)) {
        journal?.record(
          ParseRouteEvent(
            utterance: raw,
            reason: ParseRouteReason.unsupportedIntent,
            detail: intentId,
          ),
        );
        return null;
      }

      final List<Slot> slots = <Slot>[];
      final List<Doubt> doubts = <Doubt>[];

      switch (intentId) {
        case 'record_sale':
          await _parseSale(response, slots, doubts);
        case 'record_restock':
          await _parseRestock(response, slots, doubts);
        case 'query_stock':
          await _parseQueryStock(response, slots, doubts);
        case kCancelLastSaleIntent:
          break;
        case 'query_daily_stats':
          _parseDailyStats(response, slots);
        case 'query_low_stock':
          _parseLowStock(response, slots);
        case 'query_product_price':
          await _parseProductPrice(response, slots, doubts);
        case 'record_stock_out':
          await _parseStockOut(response, slots, doubts);
        case 'navigate_to_page':
          _parseNavigate(response, slots, doubts);
        case 'export_sales_report':
          _parseExportReport(response, slots, doubts);
        case 'create_product':
          _parseCreateProduct(response, slots, doubts);
        case 'update_product_price':
          await _parseUpdatePrice(response, slots, doubts);
        case 'query_sales_history':
          _parseSalesHistory(response, slots);
        case 'query_business_info':
          break;
        default:
          return null;
      }

      return CommandProposal(
        intentId: intentId,
        slots: slots,
        doubts: doubts,
        origin: ProposalOrigin.languageModel,
      );
    } on CloudCallFailure catch (failure) {
      // The call itself failed. Returning null causes CascadingParser to record the
      // failure in CircuitBreaker and fall back to the local parser; what is new is
      // that the status code survives, because a refused credential and a dropped
      // connection are not the same bug.
      journal?.record(
        ParseRouteEvent(
          utterance: raw,
          reason: ParseRouteReason.unreachable,
          detail: failure.detail,
        ),
      );
      return null;
    } catch (error) {
      journal?.record(
        ParseRouteEvent(
          utterance: raw,
          reason: answered
              ? ParseRouteReason.malformedAnswer
              : ParseRouteReason.unreachable,
          detail: '$error',
        ),
      );
      return null;
    }
  }

  Future<void> _parseSale(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final List<dynamic>? rawItems = response['items'] as List<dynamic>?;
    if (rawItems == null || rawItems.isEmpty) {
      doubts.add(const Doubt.missingProduct());
      slots.add(const Slot(name: kItemsSlot, value: <ItemMention>[]));
      return;
    }

    final List<ItemMention> mentions = <ItemMention>[];
    for (final dynamic item in rawItems) {
      if (item is! Map) continue;
      final String? productId = item['productId'] as String?;
      final num? rawQty = item['qty'] as num?;
      if (rawQty == null) {
        doubts.add(const Doubt(kind: DoubtKind.missingQuantity));
        continue;
      }
      final double qty = rawQty.toDouble();
      final double? spokenPrice = (item['spokenUnitPrice'] as num?)?.toDouble();

      if (productId == null) {
        doubts.add(const Doubt.missingProduct());
        continue;
      }

      final ProductSnapshot? product = await catalogReader.findById(productId);
      if (product == null) {
        doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
        continue;
      }
      if (product.isArchived) {
        doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
        continue;
      }
      if (qty <= 0) {
        doubts.add(const Doubt(kind: DoubtKind.invalidQuantity));
        continue;
      }

      mentions.add(
        ItemMention(product: product, qty: qty, spokenAmount: spokenPrice),
      );
    }

    slots.add(Slot(name: kItemsSlot, value: mentions));
  }

  Future<void> _parseRestock(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final List<dynamic>? rawItems = response['items'] as List<dynamic>?;
    if (rawItems == null || rawItems.isEmpty) {
      doubts.add(const Doubt.missingProduct());
      slots.add(const Slot(name: kItemsSlot, value: <ItemMention>[]));
      return;
    }

    final List<ItemMention> mentions = <ItemMention>[];
    for (final dynamic item in rawItems) {
      if (item is! Map) continue;
      final String? productId = item['productId'] as String?;
      final num? rawQty = item['qty'] as num?;
      if (rawQty == null) {
        doubts.add(const Doubt(kind: DoubtKind.missingQuantity));
        continue;
      }
      final double qty = rawQty.toDouble();
      final double? spokenCost = (item['spokenUnitCost'] as num?)?.toDouble();

      if (productId == null) {
        doubts.add(const Doubt.missingProduct());
        continue;
      }

      final ProductSnapshot? product = await catalogReader.findById(productId);
      if (product == null) {
        doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
        continue;
      }
      if (product.isArchived) {
        doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
        continue;
      }
      if (qty <= 0) {
        doubts.add(const Doubt(kind: DoubtKind.invalidQuantity));
        continue;
      }

      mentions.add(
        ItemMention(product: product, qty: qty, spokenAmount: spokenCost),
      );
    }

    slots.add(Slot(name: kItemsSlot, value: mentions));
  }

  Future<void> _parseQueryStock(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final String? productId = response['productId'] as String?;
    if (productId == null) {
      doubts.add(const Doubt.missingProduct());
      return;
    }

    final ProductSnapshot? product = await catalogReader.findById(productId);
    if (product == null) {
      doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
      return;
    }
    if (product.isArchived) {
      doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
      return;
    }

    slots.add(Slot(name: kProductIdSlot, value: product.id));
  }

  void _parseDailyStats(Map<String, dynamic> response, List<Slot> slots) {
    final String? date = response['date'] as String?;
    if (date != null && date.isNotEmpty) {
      slots.add(Slot(name: 'date', value: date));
    }
  }

  void _parseLowStock(Map<String, dynamic> response, List<Slot> slots) {
    final String? level = response['level'] as String?;
    if (level != null && level.isNotEmpty) {
      slots.add(Slot(name: 'level', value: level));
    }
  }

  Future<void> _parseProductPrice(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final String? productId = response['productId'] as String?;
    if (productId == null || productId.isEmpty) {
      doubts.add(const Doubt.missingProduct());
      return;
    }
    final ProductSnapshot? product = await catalogReader.findById(productId);
    if (product == null) {
      doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
      return;
    }
    if (product.isArchived) {
      doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
      return;
    }
    slots.add(Slot(name: kProductIdSlot, value: product.id));
  }

  Future<void> _parseStockOut(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final String? productId = response['productId'] as String?;
    final double qty = (response['qty'] as num?)?.toDouble() ?? 1.0;
    final String reason = response['reason'] as String? ?? 'breakage';
    final String? note = response['note'] as String?;

    if (productId == null || productId.isEmpty) {
      doubts.add(const Doubt.missingProduct());
      return;
    }
    final ProductSnapshot? product = await catalogReader.findById(productId);
    if (product == null) {
      doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
      return;
    }
    if (product.isArchived) {
      doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
      return;
    }
    if (qty <= 0) {
      doubts.add(const Doubt(kind: DoubtKind.invalidQuantity));
      return;
    }

    slots.add(Slot(name: kProductIdSlot, value: product.id));
    slots.add(Slot(name: 'qty', value: qty));
    slots.add(Slot(name: 'reason', value: reason));
    if (note != null) {
      slots.add(Slot(name: 'note', value: note));
    }
  }

  void _parseNavigate(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) {
    final String destination = (response['destination'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (destination.isEmpty) {
      doubts.add(const Doubt(kind: DoubtKind.outOfDomain));
      return;
    }
    slots.add(Slot(name: 'destination', value: destination));
  }

  void _parseExportReport(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) {
    final String format = (response['format'] as String? ?? 'pdf')
        .trim()
        .toLowerCase();
    final String? period = response['period'] as String?;
    slots.add(Slot(name: 'format', value: format));
    if (period != null && period.isNotEmpty) {
      slots.add(Slot(name: 'period', value: period));
    }
  }

  void _parseCreateProduct(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) {
    final String? name = response['name'] as String?;
    final double? price = (response['price'] as num?)?.toDouble();
    final double? purchasePrice = (response['purchasePrice'] as num?)
        ?.toDouble();
    final double? initialQty =
        ((response['initialQty'] ?? response['initialQuantity']) as num?)
            ?.toDouble();
    final String? category = response['category'] as String?;
    final String? unit = response['unit'] as String?;

    if (name == null || name.trim().isEmpty) {
      doubts.add(const Doubt.missingProduct());
      return;
    }
    if (price == null || price <= 0) {
      doubts.add(const Doubt(kind: DoubtKind.invalidQuantity));
      return;
    }

    slots.add(Slot(name: 'name', value: name.trim()));
    slots.add(Slot(name: 'price', value: price));
    if (purchasePrice != null) {
      slots.add(Slot(name: 'purchasePrice', value: purchasePrice));
    }
    if (initialQty != null) {
      slots.add(Slot(name: 'initialQty', value: initialQty));
    }
    if (category != null) {
      slots.add(Slot(name: 'category', value: category));
    }
    if (unit != null) {
      slots.add(Slot(name: 'unit', value: unit));
    }
  }

  Future<void> _parseUpdatePrice(
    Map<String, dynamic> response,
    List<Slot> slots,
    List<Doubt> doubts,
  ) async {
    final String? productId = response['productId'] as String?;
    final double? newPrice = (response['newPrice'] as num?)?.toDouble();

    if (productId == null || productId.isEmpty) {
      doubts.add(const Doubt.missingProduct());
      return;
    }
    final ProductSnapshot? product = await catalogReader.findById(productId);
    if (product == null) {
      doubts.add(const Doubt(kind: DoubtKind.unknownProduct));
      return;
    }
    if (product.isArchived) {
      doubts.add(const Doubt(kind: DoubtKind.archivedProduct));
      return;
    }
    if (newPrice == null || newPrice <= 0) {
      doubts.add(const Doubt(kind: DoubtKind.invalidQuantity));
      return;
    }

    slots.add(Slot(name: kProductIdSlot, value: product.id));
    slots.add(Slot(name: 'newPrice', value: newPrice));
  }

  void _parseSalesHistory(Map<String, dynamic> response, List<Slot> slots) {
    final int? limit = (response['limit'] as num?)?.toInt();
    if (limit != null && limit > 0) {
      slots.add(Slot(name: 'limit', value: limit));
    }
  }
}
