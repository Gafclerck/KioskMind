import '../../domain/ports/handler_call_journal.dart';

/// Records calls in a list, for tests and for the demo run.
final class InMemoryCallJournal implements HandlerCallJournal {
  final List<HandlerCall> _calls = <HandlerCall>[];

  @override
  void record(HandlerCall call) => _calls.add(call);

  @override
  List<HandlerCall> get calls => List<HandlerCall>.unmodifiable(_calls);

  @override
  void clear() => _calls.clear();
}
