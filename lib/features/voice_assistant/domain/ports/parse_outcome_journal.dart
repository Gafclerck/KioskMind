import '../entities/parse_route.dart';

/// Where the story of how an utterance was understood is recorded.
///
/// The cascade and the remote parser swallow their failures on purpose: a merchant
/// who loses the network must still get an answer from the rules parser. That is the
/// right behaviour, and it is also why nothing was ever diagnosable. This port is the
/// one place those swallowed facts reach, so a failure stays invisible to the
/// merchant and visible to whoever is looking for it.
///
/// An empty history is itself a finding: it means no cascade was ever built, which is
/// what a device with the cloud disabled looks like from here.
abstract interface class ParseOutcomeJournal {
  /// Records one fact. Never throws: a journal that broke the parse would turn a
  /// diagnostic into the failure it was meant to explain.
  void record(ParseRouteEvent event);

  /// Newest first. A snapshot, not a live view: reading it must not alter the run.
  List<ParseRouteEvent> get events;

  void clear();
}
