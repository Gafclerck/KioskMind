import 'package:flutter/foundation.dart';

import '../../domain/entities/parse_route.dart';
import '../../domain/ports/parse_outcome_journal.dart';

/// Prints the parse routes worth printing, and keeps them.
///
/// Only the failures are printed. A successful cloud route is the expected case and
/// printing it once per utterance turns a debug log into noise nobody reads, and a
/// log nobody reads is a log nobody reads the one time it matters.
///
/// The history is delegated rather than duplicated, so this journal and the plain one
/// hold the same events and there is no second truth about what happened.
final class LoggingParseOutcomeJournal implements ParseOutcomeJournal {
  const LoggingParseOutcomeJournal(this._inner);

  final ParseOutcomeJournal _inner;

  @override
  void record(ParseRouteEvent event) {
    if (kDebugMode && event.isFailure) {
      debugPrint('[voice] ${event.reason.name} : $event');
    }
    _inner.record(event);
  }

  @override
  List<ParseRouteEvent> get events => _inner.events;

  @override
  void clear() => _inner.clear();
}
