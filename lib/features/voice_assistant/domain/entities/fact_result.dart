/// Structured facts produced by an executed command or tool.
///
/// Ported from the assistantv3 architecture: execution produces verifiable,
/// exact facts (amounts, quantities, identifiers, statuses) rather than arbitrary
/// conversational text. The facts serve as the single source of truth for both
/// the static fallback generator and the guarded AI natural language formulator.
final class FactResult {
  const FactResult({
    required this.operation,
    required this.data,
    this.targetId,
    this.targetName,
  });

  /// The tool or command name (e.g. 'record_sale', 'query_stock', 'record_restock').
  final String operation;

  /// Pure JSON-safe dictionary of values (numbers, strings, booleans, lists).
  final Map<String, dynamic> data;

  /// Optional entity identifier (e.g. sale UUID, product id).
  final String? targetId;

  /// Optional human-readable entity name.
  final String? targetName;

  /// Recursively extracts all numeric values present in the facts.
  Set<num> extractNumbers() {
    final Set<num> numbers = <num>{};
    _collectNumbers(data, numbers);
    return numbers;
  }

  /// Extracts all code-like identifiers (e.g. 'PRD-12', 'VTC-001') present in the facts.
  Set<String> extractIdentifiers() {
    final Set<String> ids = <String>{};
    if (targetId != null && targetId!.isNotEmpty) {
      ids.add(targetId!.toLowerCase());
    }
    _collectIdentifiers(data, ids);
    return ids;
  }

  static void _collectNumbers(dynamic node, Set<num> target) {
    if (node is num) {
      target.add(node);
    } else if (node is String) {
      final num? parsed = num.tryParse(
        node.replaceAll(' ', '').replaceAll(',', '.'),
      );
      if (parsed != null) {
        target.add(parsed);
      }
    } else if (node is Map) {
      for (final dynamic value in node.values) {
        _collectNumbers(value, target);
      }
    } else if (node is Iterable) {
      for (final dynamic item in node) {
        _collectNumbers(item, target);
      }
    }
  }

  static final RegExp _identifierPattern = RegExp(
    r'(?<![A-Za-z])[A-Za-z]{2,}[-_][A-Za-z]*\d[A-Za-z0-9_-]*',
  );

  static void _collectIdentifiers(dynamic node, Set<String> target) {
    if (node is String) {
      for (final RegExpMatch match in _identifierPattern.allMatches(node)) {
        final String raw = match.group(0)!;
        target.add(raw.replaceAll(RegExp(r'\s+'), '').toLowerCase());
      }
    } else if (node is Map) {
      for (final dynamic value in node.values) {
        _collectIdentifiers(value, target);
      }
    } else if (node is Iterable) {
      for (final dynamic item in node) {
        _collectIdentifiers(item, target);
      }
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'operation': operation,
    'data': data,
    if (targetId != null) 'targetId': targetId,
    if (targetName != null) 'targetName': targetName,
  };

  @override
  String toString() => 'FactResult($operation, data: $data)';
}
