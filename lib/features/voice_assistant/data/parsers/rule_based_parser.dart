import '../../domain/entities/command_proposal.dart';
import '../../domain/entities/doubt.dart';
import '../../domain/entities/slot.dart';
import '../../domain/entities/voice_config.dart';
import '../../domain/entities/voice_lexicon.dart';
import '../../domain/ports/intent_parser.dart';
import '../../domain/services/intent_detector.dart';
import '../../domain/services/text_normalizer.dart';
import '../extractors/item_list_extractor.dart';

/// Reads one utterance into a proposal, with rules and no language model.
///
/// This is parser T1. It is pure: the same text always produces the same
/// proposal, it never writes anything, and it never decides whether the command
/// may run. It reports what it understood and what is missing or contradictory;
/// the decision policy in 1b turns that into execute, ask or refuse. Keeping the
/// verdict out of the parser is what lets a proposal be re-decided under a
/// different risk tolerance without being understood again.
///
/// A spoken word never becomes an identifier. Products are resolved by the
/// resolver against the catalog, so a name that fits nothing is a doubt to raise,
/// not a line to repair.
final class RuleBasedParser implements IntentParser {
  const RuleBasedParser({
    required this.normalizer,
    required this.detector,
    required this.items,
    this.config = const VoiceConfig(),
  });

  final TextNormalizer normalizer;
  final IntentDetector detector;
  final ItemListExtractor items;
  final VoiceConfig config;

  /// Ids whose handler writes data, and which therefore need a quantity.
  static const Set<String> _writeIntents = <String>{
    'record_sale',
    'record_restock',
  };

  /// Reads [raw] into a proposal.
  @override
  CommandProposal parse(String raw) =>
      parseNormalized(normalizer.normalize(raw));

  /// Reads an already normalized utterance.
  ///
  /// Split from [parse] so the evaluation tool can normalize once and measure
  /// several parsers on the same tokens.
  CommandProposal parseNormalized(NormalizedText text) {
    final List<String> tokens = text.tokens;
    final Doubt? refused = _refusal(tokens);
    if (refused != null) {
      return CommandProposal.rules(
        intentId: kNoIntent,
        slots: const <Slot>[],
        doubts: <Doubt>[refused],
      );
    }
    final IntentDetection? detection = detector.detect(text);
    if (detection == null) {
      return CommandProposal.rules(
        intentId: kNoIntent,
        slots: const <Slot>[],
        doubts: const <Doubt>[Doubt(kind: DoubtKind.outOfDomain)],
      );
    }
    return _propose(detection, tokens);
  }

  /// A command voice may never perform, checked before the intent is even read.
  ///
  /// "supprime le produit" names no command, so without this it would be reported
  /// as an utterance about something else instead of a refused request.
  Doubt? _refusal(List<String> tokens) {
    if (_containsAny(tokens, kDestructiveWords)) {
      return const Doubt(kind: DoubtKind.destructiveRequest);
    }
    if (_containsAny(tokens, kOrderWords)) {
      return const Doubt(kind: DoubtKind.noOrderUseCase);
    }
    if (_isUnbounded(tokens)) {
      return const Doubt(kind: DoubtKind.unboundedScope);
    }
    return null;
  }

  /// Whether "tout" means everything, rather than a moment already named.
  ///
  /// "que tout a l'heure" points back at something said before, so it is a
  /// clarification and not a command on the whole shop.
  static bool _isUnbounded(List<String> tokens) {
    for (int index = 0; index < tokens.length; index++) {
      if (!kUnboundedWords.contains(tokens[index])) {
        continue;
      }
      if (!_pointsBackInTime(tokens, index + 1)) {
        return true;
      }
    }
    return false;
  }

  static bool _pointsBackInTime(List<String> tokens, int from) {
    final int limit = from + kPastReferenceReach;
    for (int index = from; index < limit && index < tokens.length; index++) {
      if (tokens[index] == kPastReferenceTail) {
        return true;
      }
    }
    return false;
  }

  CommandProposal _propose(IntentDetection detection, List<String> tokens) {
    final bool isWrite = _writeIntents.contains(detection.intentId);
    final List<Doubt> doubts = _markerDoubts(tokens, isWrite);
    final List<Slot> slots = switch (detection.intentId) {
      'cancel_last_sale' => _cancelSlots(),
      'query_stock' => _querySlots(detection, tokens, doubts),
      _ => _itemSlots(detection, tokens, doubts, isWrite),
    };
    return CommandProposal.rules(
      intentId: detection.intentId,
      slots: slots,
      doubts: doubts,
    );
  }

  /// Doubts raised by the words around the command, whatever it turned out to be.
  List<Doubt> _markerDoubts(List<String> tokens, bool isWrite) {
    final List<Doubt> doubts = <Doubt>[];
    for (final DoubtMarker marker in kDoubtMarkers) {
      if (_containsAny(tokens, marker.words)) {
        doubts.add(Doubt(kind: marker.kind));
      }
    }
    if (!isWrite) {
      return doubts;
    }
    for (final MapEntry<DoubtKind, Set<String>> entry
        in kWriteOnlyDoubtMarkers.entries) {
      if (_containsAny(tokens, entry.value)) {
        doubts.add(Doubt(kind: entry.key));
      }
    }
    return doubts;
  }

  /// A sale or a restock: the products named, and what each line is missing.
  List<Slot> _itemSlots(
    IntentDetection detection,
    List<String> tokens,
    List<Doubt> doubts,
    bool isWrite,
  ) {
    if (_containsAny(tokens, kPriceQuestionWords)) {
      doubts.add(const Doubt(kind: DoubtKind.outOfScope));
    }
    final ItemListReading reading = items.read(
      tokens,
      from: detection.triggerEnd,
      requiresQuantity: isWrite,
    );
    doubts.addAll(reading.doubts);
    if (reading.items.isEmpty) {
      return const <Slot>[];
    }
    return <Slot>[Slot(name: 'items', value: reading.items)];
  }

  /// A stock question: the product asked about, and nothing else.
  ///
  /// A question carries no quantity, so the product is read from the names rather
  /// than from the lines.
  List<Slot> _querySlots(
    IntentDetection detection,
    List<String> tokens,
    List<Doubt> doubts,
  ) {
    final ItemListReading reading = items.read(
      tokens,
      from: detection.triggerEnd,
      requiresQuantity: false,
    );
    doubts.addAll(reading.doubts);
    if (reading.products.isEmpty) {
      return const <Slot>[];
    }
    return <Slot>[Slot(name: kProductIdSlot, value: reading.products.first.id)];
  }

  /// A cancellation names no slot: the sale is the last one of the session.
  static List<Slot> _cancelSlots() => <Slot>[
    Slot(name: 'saleId', value: kLastSaleIdPlaceholder),
  ];

  static bool _containsAny(List<String> tokens, Set<String> words) {
    for (final String token in tokens) {
      if (words.contains(token)) {
        return true;
      }
    }
    return false;
  }
}
