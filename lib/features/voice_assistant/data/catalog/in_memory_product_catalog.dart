import '../../domain/entities/intent_result.dart';
import '../../domain/entities/product_snapshot.dart';
import '../../domain/ports/command_context.dart';
import '../../domain/ports/product_catalog_reader.dart';

/// A persisted sale, as the mock store exposes it to assertions.
///
/// The contract suite checks this shape against the mock now and against a real
/// Firestore document in phase I, so the record must stay the document shape:
/// codes, copied names, device clock, no localized text.
typedef StoredSale = ({
  String saleId,
  String commandId,
  String source,
  DateTime dateTime,
  double total,
  DateTime? cancelledAt,
  List<SaleLineResult> lines,
});

typedef StoredMovement = ({
  String id,
  String productId,
  String type,
  double delta,
  double? unitCost,
  DateTime dateTime,
});

/// In-memory double of what `products`, `sales` and `stockMovements` hold.
///
/// Doubles as the catalog read model and as the writable state behind the mock
/// handlers, so the mocks behave like a shop: a sale lowers the stock, a
/// cancellation gives it back, an unknown product changes nothing.
///
/// Writes apply in one step, never partially: a handler that computes all its
/// lines before calling a write method here gets the atomicity a Firestore
/// batch gives for free.
final class InMemoryProductCatalog implements ProductCatalogReader {
  InMemoryProductCatalog(List<ProductSnapshot> products)
    : _products = <String, ProductSnapshot>{
        for (final ProductSnapshot product in products) product.id: product,
      };

  final Map<String, ProductSnapshot> _products;
  final Map<String, StoredSale> _sales = <String, StoredSale>{};
  final Map<String, String> _saleIdByCommandId = <String, String>{};
  final List<StoredMovement> _movements = <StoredMovement>[];

  @override
  Future<List<ProductSnapshot>> readActiveProducts() async {
    final List<ProductSnapshot> active =
        _products.values
            .where((ProductSnapshot product) => !product.isArchived)
            .toList()
          ..sort(
            (ProductSnapshot a, ProductSnapshot b) => a.name.compareTo(b.name),
          );
    return active;
  }

  @override
  Future<ProductSnapshot?> findById(String productId) async =>
      productById(productId);

  /// The product whatever its archived flag, so a caller can tell an archived
  /// product from an unknown one.
  ProductSnapshot? productById(String productId) => _products[productId];

  double? stockOf(String productId) => _products[productId]?.stock;

  /// Previous successful result for this command identifier, if any. A replayed
  /// command returns it instead of writing twice (contract A3).
  RecordSaleResult? saleResultByCommandId(String commandId) {
    final String? saleId = _saleIdByCommandId[commandId];
    if (saleId == null) {
      return null;
    }
    final StoredSale? sale = _sales[saleId];
    if (sale == null || sale.cancelledAt != null) {
      return null;
    }
    return (saleId: sale.saleId, total: sale.total, lines: sale.lines);
  }

  StoredSale? saleById(String saleId) => _sales[saleId];

  List<StoredMovement> get movements =>
      List<StoredMovement>.unmodifiable(_movements);

  void applySale(CommandContext context, RecordSaleResult result) {
    if (_saleIdByCommandId.containsKey(context.commandId)) {
      return;
    }
    for (final SaleLineResult line in result.lines) {
      _adjustStock(line.productId, -line.qty);
    }
    _sales[result.saleId] = (
      saleId: result.saleId,
      commandId: context.commandId,
      source: context.source.code,
      dateTime: context.dateTime,
      total: result.total,
      cancelledAt: null,
      lines: result.lines,
    );
    _saleIdByCommandId[context.commandId] = result.saleId;
  }

  void applyRestock(CommandContext context, RecordRestockResult result) {
    for (int index = 0; index < result.lines.length; index++) {
      final RestockLineResult line = result.lines[index];
      _adjustStock(line.productId, line.qty);
      _movements.add((
        id: result.movementIds[index],
        productId: line.productId,
        type: 'PURCHASE',
        delta: line.qty,
        unitCost: line.appliedUnitCost,
        dateTime: context.dateTime,
      ));
    }
  }

  void applyCancellation(
    String saleId,
    DateTime cancelledAt,
    List<SaleLineResult> restored,
  ) {
    final StoredSale? sale = _sales[saleId];
    if (sale == null || sale.cancelledAt != null) {
      return;
    }
    for (final SaleLineResult line in restored) {
      _adjustStock(line.productId, line.qty);
    }
    _sales[saleId] = (
      saleId: sale.saleId,
      commandId: sale.commandId,
      source: sale.source,
      dateTime: sale.dateTime,
      total: sale.total,
      cancelledAt: cancelledAt,
      lines: sale.lines,
    );
  }

  void _adjustStock(String productId, double delta) {
    // Callers pass product identifiers they have just validated against this
    // catalog, and it never deletes a product, so one is always present.
    final ProductSnapshot product = _products[productId]!;
    _products[productId] = product.withStock(product.stock + delta);
  }
}
