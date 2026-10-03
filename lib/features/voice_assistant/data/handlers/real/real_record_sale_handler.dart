import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../sales/domain/entities/sale.dart';
import '../../../../sales/domain/usecases/record_sale.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/entities/product_snapshot.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';
import '../../../domain/ports/product_catalog_reader.dart';
import '../canonical_arguments.dart';

/// Real implementation of the sale use case handler, calling the sales feature.
///
/// Follows the contract of `docs/voice/USE_CASE_CONTRACTS.md`:
/// - Catalog price is applied
/// - Stock may go negative
/// - Replayed command returns the previous result without duplicate write
/// - Exceptions crossing the boundary are converted to typed Failures
final class RealRecordSaleHandler implements RecordSaleHandler {
  RealRecordSaleHandler({
    required this.recordSale,
    required this.catalogReader,
  });

  final RecordSale recordSale;
  final ProductCatalogReader catalogReader;
  final Map<String, RecordSaleResult> _recordedCommands =
      <String, RecordSaleResult>{};

  @override
  String get intentId => 'record_sale';

  @override
  Future<Result<RecordSaleResult>> execute(
    CommandContext context,
    SaleIntentInput input,
  ) async {
    if (input.items.isEmpty) {
      return Failed<RecordSaleResult>(const EmptyItems('record_sale'));
    }

    final RecordSaleResult? replayed = _recordedCommands[context.commandId];
    if (replayed != null) {
      return Success<RecordSaleResult>(replayed);
    }

    final List<SaleLineResult> lines = <SaleLineResult>[];
    for (final SaleIntentLine item in input.items) {
      final Result<SaleLineResult> lineResult = await _line(item);
      switch (lineResult) {
        case Failed<SaleLineResult>(:final Failure failure):
          return Failed<RecordSaleResult>(failure);
        case Success<SaleLineResult>(:final SaleLineResult value):
          lines.add(value);
      }
    }

    final double total = roundAmount(
      lines.fold<double>(
        0,
        (double sum, SaleLineResult line) =>
            sum + line.qty * line.appliedUnitPrice,
      ),
    );

    final Sale saleEntity = Sale(
      id: context.commandId,
      dateTime: context.dateTime,
      createdAt: context.dateTime,
      total: total,
      items: <SaleItem>[
        for (final SaleLineResult line in lines)
          SaleItem(
            productId: line.productId,
            name: line.name,
            qty: line.qty,
            unitPrice: line.appliedUnitPrice,
          ),
      ],
      source: context.source.name.toUpperCase(),
      status: 'COMPLETED',
    );

    try {
      final Sale saved = await recordSale(saleEntity);
      final RecordSaleResult result = (
        saleId: saved.id ?? context.commandId,
        total: total,
        lines: lines,
      );
      _recordedCommands[context.commandId] = result;
      return Success<RecordSaleResult>(result);
    } on Exception catch (_) {
      return Failed<RecordSaleResult>(
        UnknownProduct(productId: input.items.first.productId),
      );
    }
  }

  Future<Result<SaleLineResult>> _line(SaleIntentLine item) async {
    final ProductSnapshot? product = await catalogReader.findById(
      item.productId,
    );
    if (product == null) {
      return Failed<SaleLineResult>(UnknownProduct(productId: item.productId));
    }
    if (product.isArchived) {
      return Failed<SaleLineResult>(
        ArchivedProduct(productId: product.id, productName: product.name),
      );
    }
    if (item.qty <= 0) {
      return Failed<SaleLineResult>(
        InvalidQuantity(productId: product.id, qty: item.qty),
      );
    }
    return Success<SaleLineResult>((
      productId: product.id,
      name: product.name,
      unit: product.unit,
      qty: item.qty,
      appliedUnitPrice: product.price,
      resultingStock: product.stock - item.qty,
    ));
  }
}
