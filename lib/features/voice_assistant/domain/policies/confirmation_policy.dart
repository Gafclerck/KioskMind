/// Policy deciding whether a tool requires confirmation before execution.
///
/// Ported from assistantv3 `policies/confirmation.py`:
/// Instead of a static boolean flag, policies are objects declared by each tool.
abstract interface class ConfirmationPolicy {
  String get kind;

  /// Returns true if confirmation is required for the given [params].
  bool requires(Map<String, dynamic> params);
}

final class NeverConfirmation implements ConfirmationPolicy {
  const NeverConfirmation();

  @override
  String get kind => 'never';

  @override
  bool requires(Map<String, dynamic> params) => false;
}

final class AlwaysConfirmation implements ConfirmationPolicy {
  const AlwaysConfirmation();

  @override
  String get kind => 'always';

  @override
  bool requires(Map<String, dynamic> params) => true;
}

final class ThresholdConfirmation implements ConfirmationPolicy {
  const ThresholdConfirmation({required this.amountField, required this.limit});

  final String amountField;
  final double limit;

  @override
  String get kind => 'threshold';

  @override
  bool requires(Map<String, dynamic> params) {
    final dynamic raw = params[amountField];
    if (raw == null) return false;
    final num? amount = raw is num ? raw : num.tryParse(raw.toString());
    if (amount == null) return true; // Be conservative on unreadable amounts
    return amount > limit;
  }
}

final class PredicateConfirmation implements ConfirmationPolicy {
  const PredicateConfirmation(this._predicate);

  final bool Function(Map<String, dynamic> params) _predicate;

  @override
  String get kind => 'predicate';

  @override
  bool requires(Map<String, dynamic> params) => _predicate(params);
}
