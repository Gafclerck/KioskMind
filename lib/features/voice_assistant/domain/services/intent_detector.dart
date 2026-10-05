import '../entities/intent_definition.dart';
import 'text_normalizer.dart';

/// Which command an utterance asks for, and where that command starts.
///
/// The end of the trigger is kept because the words after it are where the
/// product is expected: "vendu un truc" has a word where a product should be,
/// and "vendu deux sachets" has only a unit. Telling those apart needs to know
/// where the command ended.
/// Which command an utterance asks for, and where that command starts.
///
/// Both the start and end of the trigger are kept so that the parser can inspect
/// products and arguments both before and after the trigger, supporting flexible
/// utterance order.
final class IntentDetection {
  const IntentDetection({
    required this.intentId,
    required this.triggerEnd,
    this.triggerStart = 0,
  });

  final String intentId;

  /// Index of the first token of the trigger that matched.
  final int triggerStart;

  /// Index just past the last token of the trigger that matched.
  final int triggerEnd;
}

final class _TriggerMatch {
  const _TriggerMatch({required this.start, required this.end});

  final int start;
  final int end;
}

/// Which command an utterance asks for, read from the triggers of the catalog.
///
/// The catalog is the single source: adding a command is a catalog entry, and
/// this class needs no change for it. Matching is exact and token-based, so a
/// trigger only fires on the wording the catalog declares, and it is run through
/// the same normalization as the transcript so "j'ai vendu" and "jai vendu" are
/// the same trigger.
final class IntentDetector {
  IntentDetector({required this.catalog, required TextNormalizer normalizer})
    : _triggers = <String, List<String>>{
        for (final IntentDefinition intent in catalog.offlineIntents)
          intent.id: <String>[
            for (final String trigger in intent.triggers)
              normalizer.normalize(trigger).text,
          ],
      };

  final IntentCatalog catalog;

  /// Triggers already normalized, per intent.
  final Map<String, List<String>> _triggers;

  /// The command the utterance asks for, or null when it names none.
  ///
  /// The longest trigger wins, which is what makes "il reste combien" beat a bare
  /// "combien" without a hardcoded list of priorities. A tie is kept as the first
  /// one found in catalog order, so the result never depends on map iteration.
  IntentDetection? detect(NormalizedText text) {
    final List<String> tokens = text.tokens;
    IntentDetection? best;
    int bestLength = 0;
    for (final IntentDefinition intent in catalog.offlineIntents) {
      for (final String trigger in _triggers[intent.id] ?? const <String>[]) {
        if (trigger.isEmpty) {
          continue;
        }
        final int length = trigger.split(' ').length;
        if (length <= bestLength) {
          continue;
        }
        final _TriggerMatch? match = _matchAt(tokens, trigger);
        if (match == null) {
          continue;
        }
        best = IntentDetection(
          intentId: intent.id,
          triggerStart: match.start,
          triggerEnd: match.end,
        );
        bestLength = length;
      }
    }
    return best;
  }

  /// Match range when the trigger appears as consecutive tokens, else null.
  static _TriggerMatch? _matchAt(List<String> tokens, String trigger) {
    final List<String> parts = trigger.split(' ');
    for (int start = 0; start + parts.length <= tokens.length; start++) {
      if (_matchesAt(tokens, start, parts)) {
        return _TriggerMatch(start: start, end: start + parts.length);
      }
    }
    return null;
  }

  static bool _matchesAt(List<String> tokens, int start, List<String> parts) {
    for (int offset = 0; offset < parts.length; offset++) {
      if (tokens[start + offset] != parts[offset]) {
        return false;
      }
    }
    return true;
  }
}
