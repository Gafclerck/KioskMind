import 'dart:collection';

import '../../domain/entities/parse_route.dart';
import '../../domain/ports/parse_outcome_journal.dart';

/// Keeps the last few parse routes, newest first.
///
/// Bounded on purpose. The history exists to explain the utterance a merchant is
/// looking at, and a merchant looking at a bug wants the last few, not the whole
/// session: an unbounded list on a device that lives in a pocket is a leak wearing a
/// diagnostic's clothes.
final class InMemoryParseOutcomeJournal implements ParseOutcomeJournal {
  InMemoryParseOutcomeJournal({this.capacity = kDefaultParseJournalCapacity});

  /// How many routes are kept. Enough to cover one debugging session of look-ups
  /// without growing without end.
  static const int kDefaultParseJournalCapacity = 30;

  final int capacity;
  final Queue<ParseRouteEvent> _events = Queue<ParseRouteEvent>();

  @override
  void record(ParseRouteEvent event) {
    _events.addFirst(event);
    while (_events.length > capacity) {
      _events.removeLast();
    }
  }

  @override
  List<ParseRouteEvent> get events =>
      List<ParseRouteEvent>.unmodifiable(_events);

  @override
  void clear() => _events.clear();
}
