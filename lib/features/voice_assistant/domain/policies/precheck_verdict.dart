/// What a domain precheck returns before confirmation or execution.
///
/// Ported from assistantv3 `policies/precheck.py`:
/// Instead of a binary success/fail, a precheck can guide the user by asking
/// for clarification with selectable choices, avoiding dead-ends.
sealed class PrecheckVerdict {
  const PrecheckVerdict();

  static const PrecheckVerdict ok = _OkVerdict();
  static PrecheckVerdict refuse(String message) => _RefuseVerdict(message);
  static PrecheckVerdict ask({
    required String field,
    required String question,
    List<Map<String, dynamic>> choices = const <Map<String, dynamic>>[],
  }) => _AskVerdict(field: field, question: question, choices: choices);
}

final class _OkVerdict extends PrecheckVerdict {
  const _OkVerdict();

  @override
  String toString() => 'PrecheckVerdict.ok';
}

final class _RefuseVerdict extends PrecheckVerdict {
  const _RefuseVerdict(this.message);
  final String message;

  @override
  String toString() => 'PrecheckVerdict.refuse($message)';
}

final class _AskVerdict extends PrecheckVerdict {
  const _AskVerdict({
    required this.field,
    required this.question,
    this.choices = const <Map<String, dynamic>>[],
  });

  final String field;
  final String question;
  final List<Map<String, dynamic>> choices;

  @override
  String toString() =>
      'PrecheckVerdict.ask($field, $question, choices: $choices)';
}
