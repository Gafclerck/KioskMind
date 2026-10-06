import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/entities/slot.dart';
import '../../domain/ports/intent_handler.dart';
import 'voice_outcome.dart';

/// What the merchant is about to authorise, read before he answers.
///
/// A confirmation is the one screen where a wrong tap costs something, so it shows
/// the command rather than the transcript it was understood from. This is that
/// command, projected into the shape a recap is drawn from: the same
/// [VoiceRecapLine] a completed recap uses, plus the plain values an intent that
/// touches no line still has to name.
///
/// [intentId] stays on it so the text can name the operation, and every [detail]
/// keeps a stable key so its wording lives with every other wording, in
/// `voice_message_text.dart`, instead of next to the parsing that produced it.
final class VoiceRecap {
  const VoiceRecap({
    required this.intentId,
    this.lines = const <VoiceRecapLine>[],
    this.details = const <VoiceRecapDetail>[],
  });

  /// The command as the catalog names it.
  final String intentId;

  /// The products the command touches, in spoken order. Empty for an intent that
  /// names none, which is most of the read tools.
  final List<VoiceRecapLine> lines;

  /// The values the merchant is being shown, in the order they matter to him.
  final List<VoiceRecapDetail> details;

  /// Whether there is anything to read. A recap of nothing is not a recap, so the
  /// screen falls back to the transcript rather than print an empty confirmation.
  bool get hasContent => lines.isNotEmpty || details.isNotEmpty;
}

/// One value of a recap, as a stable key and what the merchant said.
///
/// The key is a machine word rather than a sentence because the sentence is the
/// locale's business: a key nothing knows how to say is a recap printing its own
/// key at the merchant.
typedef VoiceRecapDetail = ({String key, double? amount, String? text});

/// Looks the product an id names up, for a recap that has only the id.
///
/// A proposal names a product by id whenever the parser resolved it against the
/// catalog, and an id is how the module refers to a product rather than how a
/// merchant reads one. The recap therefore asks the catalog for the name, and the
/// caller is the one that already holds a reader.
typedef RecapProductLookup = Future<ProductSnapshot?> Function(String productId);

/// The recap of the command a question is about, or null when it names none.
///
/// One switch rather than one per screen, for the reason [outcomeOfValue] is one:
/// the rule "what does this intent show" is written once, here, and no widget ever
/// learns an intent id.
///
/// Null when the proposal names an intent the catalog does not describe, so a
/// command nothing reviewed is never drawn as though it had been.
Future<VoiceRecap?> pendingRecapOf(
  CommandProposal proposal,
  RecapProductLookup byId,
) async {
  final String? productId = _productIdOf(proposal);
  return switch (proposal.intentId) {
    'record_sale' || 'record_restock' => VoiceRecap(
      intentId: proposal.intentId,
      lines: _lineRecap(proposal),
      details: _announcedAmounts(proposal),
    ),
    'query_stock' || 'query_product_price' => VoiceRecap(
      intentId: proposal.intentId,
      lines: await _productRecap(proposal, productId, byId),
    ),
    kCancelLastSaleIntent => VoiceRecap(intentId: proposal.intentId),
    'record_stock_out' => VoiceRecap(
      intentId: proposal.intentId,
      lines: await _productRecap(proposal, productId, byId),
      details: <VoiceRecapDetail>[
        (key: 'qty', amount: proposal.valueOf<double>('qty'), text: null),
        (key: 'reason', amount: null, text: proposal.valueOf<String>('reason')),
        (key: 'note', amount: null, text: proposal.valueOf<String>('note')),
      ],
    ),
    'update_product_price' => VoiceRecap(
      intentId: proposal.intentId,
      lines: await _productRecap(proposal, productId, byId),
      details: <VoiceRecapDetail>[
        (
          key: 'newPrice',
          amount: proposal.valueOf<double>('newPrice'),
          text: null,
        ),
      ],
    ),
    'create_product' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (key: 'name', amount: null, text: proposal.valueOf<String>('name')),
        (key: 'price', amount: proposal.valueOf<double>('price'), text: null),
        (
          key: 'purchasePrice',
          amount: proposal.valueOf<double>('purchasePrice'),
          text: null,
        ),
        (
          key: 'initialQty',
          amount: proposal.valueOf<double>('initialQty'),
          text: null,
        ),
      ],
    ),
    'navigate_to_page' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (
          key: 'destination',
          amount: null,
          text: proposal.valueOf<String>('destination'),
        ),
      ],
    ),
    'export_sales_report' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (
          key: 'format',
          amount: null,
          text: proposal.valueOf<String>('format'),
        ),
        (key: 'period', amount: null, text: proposal.valueOf<String>('period')),
      ],
    ),
    'query_daily_stats' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (key: 'date', amount: null, text: proposal.valueOf<String>('date')),
      ],
    ),
    'query_low_stock' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (key: 'level', amount: null, text: proposal.valueOf<String>('level')),
      ],
    ),
    'query_sales_history' => VoiceRecap(
      intentId: proposal.intentId,
      details: <VoiceRecapDetail>[
        (key: 'limit', amount: null, text: _countText(proposal)),
      ],
    ),
    'query_business_info' => VoiceRecap(intentId: proposal.intentId),
    _ => null,
  };
}

/// The lines a line-based command carries, in spoken order.
List<VoiceRecapLine> _lineRecap(CommandProposal proposal) {
  return <VoiceRecapLine>[
    for (final ItemMention mention in _mentions(proposal))
      (
        name: mention.product.name,
        qty: mention.qty,
        unit: mention.product.unit,
        // The catalog's price, not a price yet applied: nothing has run, so this is
        // what the line would be worth unless the merchant named another amount.
        unitPrice: mention.product.price,
      ),
  ];
}

/// The one product a command names, as a line of the recap.
///
/// The quantity is zero because a read and a price change move nothing, and
/// printing a count next to the name would be a figure the merchant never said.
/// When the catalog cannot name the id, no line is drawn rather than the id is:
/// a recap showing "prod-sucre" is worse than a recap showing nothing.
Future<List<VoiceRecapLine>> _productRecap(
  CommandProposal proposal,
  String? productId,
  RecapProductLookup byId,
) async {
  if (productId == null) {
    return const <VoiceRecapLine>[];
  }
  for (final ItemMention mention in _mentions(proposal)) {
    if (mention.product.id == productId) {
      // A named product with no quantity: a read or a price change moves nothing, so
      // it has no line total to show and no price to apply.
      return <VoiceRecapLine>[
        (
          name: mention.product.name,
          qty: 0,
          unit: null,
          unitPrice: null,
        ),
      ];
    }
  }
  final ProductSnapshot? named = await byId(productId);
  if (named == null) {
    return const <VoiceRecapLine>[];
  }
  return <VoiceRecapLine>[
    (name: named.name, qty: 0, unit: null, unitPrice: null),
  ];
}

/// The amounts the merchant announced on the lines, which the recap repeats.
///
/// A doubt about one of them is why a confirmation is being asked at all, so
/// hiding it from the recap would ask the merchant to agree to a figure he is
/// never shown.
List<VoiceRecapDetail> _announcedAmounts(CommandProposal proposal) {
  return <VoiceRecapDetail>[
    for (final ItemMention mention in _mentions(proposal))
      if (mention.spokenAmount case final double amount)
        (key: 'spokenAmount', amount: amount, text: mention.product.name),
  ];
}

/// The product id the proposal carries, or null when it carries none.
String? _productIdOf(CommandProposal proposal) {
  final String? productId = proposal.valueOf<String>(kProductIdSlot);
  return (productId == null || productId.isEmpty) ? null : productId;
}

List<ItemMention> _mentions(CommandProposal proposal) {
  return proposal.valueOf<List<ItemMention>>(kItemsSlot) ??
      const <ItemMention>[];
}

/// The count a history question carries, as the digits the recap prints.
String? _countText(CommandProposal proposal) {
  final int? limit = proposal.valueOf<int>('limit');
  return limit?.toString();
}