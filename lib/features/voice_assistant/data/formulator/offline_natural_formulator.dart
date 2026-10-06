import '../../domain/entities/fact_result.dart';
import '../../domain/ports/message_formulator.dart';
import '../../domain/services/spoken_amount_formatter.dart';

/// Offline implementation of [MessageFormulator].
///
/// Produces natural, fluent, and warm West African shopkeeper conversational responses
/// completely locally without internet connection or LLM latency.
///
/// Eliminates the rigid robotic concatenation ("Vente 1 - 2 Riz - Total 1000 FCFA")
/// while guaranteeing zero risk of failure or delay.
final class OfflineNaturalFormulator implements MessageFormulator {
  const OfflineNaturalFormulator({SpokenAmountFormatter? amountsFormatter})
    : _amounts = amountsFormatter ?? const SpokenAmountFormatter();

  final SpokenAmountFormatter _amounts;

  @override
  Future<String> formulate({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) async => formatSync(
    userUtterance: userUtterance,
    facts: facts,
    staticFallback: staticFallback,
  );

  /// Synchronous formulation for instant zero-latency rendering.
  @override
  String formatSync({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) {
    if (facts.isEmpty) {
      return staticFallback;
    }

    final List<String> segments = <String>[];
    for (final FactResult fact in facts) {
      final String? segment = _formulateFact(fact);
      if (segment != null && segment.isNotEmpty) {
        segments.add(segment);
      }
    }

    if (segments.isEmpty) {
      return staticFallback;
    }

    if (segments.length == 1) {
      return segments.first;
    }

    // Consolidated formulation for multiple operations in one turn
    return segments.join(' Et ');
  }

  String? _formulateFact(FactResult fact) {
    switch (fact.operation) {
      case 'record_sale':
        return _formulateSale(fact.data);
      case 'record_restock':
        return _formulateRestock(fact.data);
      case 'query_stock':
        return _formulateStock(fact.data);
      case 'cancel_last_sale':
        return "C'est fait, la dernière vente a bien été annulée et le stock est remis en place.";
      default:
        return null;
    }
  }

  String _formulateSale(Map<String, dynamic> data) {
    final List<dynamic>? items = data['items'] as List<dynamic>?;
    final num total = data['total'] as num? ?? 0;
    final String currency = data['currency'] as String? ?? 'FCFA';
    final String formattedTotal = '${_amounts(total.toDouble())} $currency';

    final int count = items?.length ?? 0;
    final String lineCountStr = count == 1
        ? 'Une ligne enregistrée'
        : '$count lignes enregistrées';

    if (items == null || items.isEmpty) {
      return "Vente enregistrée ($lineCountStr), total $formattedTotal.";
    }

    final List<String> itemDescriptions = <String>[];
    for (final dynamic it in items) {
      if (it is Map) {
        final String name =
            it['product'] as String? ?? it['name'] as String? ?? 'produit';
        final num qty = it['qty'] as num? ?? 1;
        final String? unit = it['unit'] as String?;
        final String qtyStr = _formatQty(qty);
        if (unit != null && unit.isNotEmpty && unit != 'piece') {
          itemDescriptions.add('$qtyStr $unit de $name');
        } else {
          itemDescriptions.add('$qtyStr $name');
        }
      }
    }

    final String itemsPhrase = itemDescriptions.join(', ');
    return "Vente enregistrée ($lineCountStr) : $itemsPhrase, total $formattedTotal.";
  }

  String _formulateRestock(Map<String, dynamic> data) {
    final List<dynamic>? items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return "L'entrée en stock a bien été enregistrée.";
    }

    final List<String> itemDescriptions = <String>[];
    for (final dynamic it in items) {
      if (it is Map) {
        final String name =
            it['product'] as String? ?? it['name'] as String? ?? 'produit';
        final num qty = it['qty'] as num? ?? 1;
        final String? unit = it['unit'] as String?;
        final String qtyStr = _formatQty(qty);
        if (unit != null && unit.isNotEmpty && unit != 'piece') {
          itemDescriptions.add('$qtyStr $unit de $name');
        } else {
          itemDescriptions.add('$qtyStr $name');
        }
      }
    }

    return "Réapprovisionnement validé : ${itemDescriptions.join(', ')} bien ajoutés au stock.";
  }

  String _formulateStock(Map<String, dynamic> data) {
    final String product = data['product'] as String? ?? 'ce produit';
    final num stock = data['stock'] as num? ?? 0;
    final String? unit = data['unit'] as String?;
    final String qtyStr = _formatQty(stock);

    if (stock <= 0) {
      return "Attention, il n'y a plus de stock pour $product (rupture de stock).";
    }

    final String unitStr = (unit != null && unit.isNotEmpty && unit != 'piece')
        ? ' $unit'
        : '';
    return "Il vous reste actuellement $qtyStr$unitStr de $product en magasin.";
  }

  String _formatQty(num qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toString().replaceAll('.', ',');
  }
}
