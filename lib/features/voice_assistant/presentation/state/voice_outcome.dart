import '../../../../core/usecase/result.dart';
import '../../domain/entities/intent_result.dart';
import '../../domain/usecases/execute_command.dart';

/// One line of a recap, as the merchant is told about it.
///
/// [unit] is the code the catalog uses, and null when the use case that wrote the
/// line did not report one: the contract of a restock carries no unit, and a recap
/// invents nothing.
typedef VoiceRecapLine = ({String name, double qty, String? unit});

/// What a command actually did, in the shape a recap needs.
///
/// The domain already returns exactly what happened, per intent. What it does not
/// return is one type: a screen cannot switch over four record types without
/// knowing each intent's shape, and a switch per intent in every widget is a rule
/// written three times. This is that one place, and it is presentation: it adds
/// no fact, it only reads the ones the handler reported.
sealed class VoiceOutcome {
  const VoiceOutcome();
}

/// Lines were sold, and the session may undo them.
final class SaleRecorded extends VoiceOutcome {
  const SaleRecorded({required this.lines, required this.total});

  final List<VoiceRecapLine> lines;

  /// Total in francs, read in words because a synthesiser reads "1250" badly.
  final double total;
}

/// Stock was added. Nothing to undo: the cancellation handler knows sales only.
final class RestockRecorded extends VoiceOutcome {
  const RestockRecorded(this.lines);

  final List<VoiceRecapLine> lines;
}

/// The stock of one product was read.
final class StockRead extends VoiceOutcome {
  const StockRead({
    required this.product,
    required this.stock,
    required this.unit,
  });

  final String product;

  final double stock;

  final String unit;
}

/// The sale of the undo window was cancelled and its stock given back.
final class SaleCancelled extends VoiceOutcome {
  const SaleCancelled(this.lines);

  final List<VoiceRecapLine> lines;
}

/// What [execution] did, or null when it did not run a handler.
///
/// Null covers both "held" and "failed": in those two cases what the merchant is
/// told is about the doubt, not about a result, and the doubt is what the caller
/// already has.
VoiceOutcome? outcomeOf(CommandExecution execution) {
  if (execution is! ExecutedCommand) {
    return null;
  }
  return switch (execution.result) {
    Failed<Object>() => null,
    Success<Object>(value: final Object value) => outcomeOfValue(value),
  };
}

/// The outcome of one handler answer, or null for a shape nobody knows.
///
/// A handler this module has no use case for would land here, and the null keeps
/// it out of the recap rather than printing a record the merchant cannot read.
VoiceOutcome? outcomeOfValue(Object value) {
  return switch (value) {
    final RecordSaleResult result => SaleRecorded(
      lines: _saleLines(result.lines),
      total: result.total,
    ),
    final RecordRestockResult result => RestockRecorded(<VoiceRecapLine>[
      for (final RestockLineResult line in result.lines)
        (name: line.name, qty: line.qty, unit: null),
    ]),
    final QueryStockResult result => StockRead(
      product: result.productName,
      stock: result.stock,
      unit: result.unit,
    ),
    final CancelLastSaleResult result => SaleCancelled(
      _saleLines(result.restored),
    ),
    _ => null,
  };
}

List<VoiceRecapLine> _saleLines(List<SaleLineResult> lines) {
  return <VoiceRecapLine>[
    for (final SaleLineResult line in lines)
      (name: line.name, qty: line.qty, unit: line.unit),
  ];
}
