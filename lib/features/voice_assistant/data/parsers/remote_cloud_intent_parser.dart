import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/doubt.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/entities/slot.dart';
import '../../domain/ports/cloud_intent_parser.dart';
import '../../domain/ports/intent_handler.dart';
import '../../domain/ports/product_catalog_reader.dart';

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
final class RemoteCloudIntentParser implements CloudIntentParser {
  RemoteCloudIntentParser({
    required this.catalogReader,
    CloudFunctionCaller? cloudCaller,
  }) : _cloudCaller = cloudCaller ?? _defaultFirebaseCaller;

  final ProductCatalogReader catalogReader;
  final CloudFunctionCaller _cloudCaller;

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

      final String? intentId = response['intentId'] as String?;
      if (intentId == null || !kSupportedIntentIds.contains(intentId)) {
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
        default:
          return null;
      }

      return CommandProposal(
        intentId: intentId,
        slots: slots,
        doubts: doubts,
        origin: ProposalOrigin.languageModel,
      );
    } catch (_) {
      // Remote call or parsing failure: returning null causes CascadingParser
      // to record the failure in CircuitBreaker and fall back to local parser.
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
      final double qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
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
      final double qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
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

    slots.add(Slot(name: kProductIdSlot, value: product));
  }
}
