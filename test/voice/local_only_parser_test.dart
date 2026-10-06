import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/diagnostics/in_memory_parse_outcome_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/parse_route.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/local_only_parser.dart';

/// A device with no key answers exactly like a device that understood nothing, and
/// that is the whole problem this parser exists to name. These tests pin the naming
/// rather than the answering: the answer must not change, or merchants would feel it,
/// but the reason must be written down or it will never be found.

void main() {
  late InMemoryParseOutcomeJournal journal;
  late _CountingRules rules;
  late LocalOnlyParser parser;

  setUp(() {
    journal = InMemoryParseOutcomeJournal();
    rules = _CountingRules();
    parser = LocalOnlyParser(
      local: rules,
      reason: ParseRouteReason.noCredential,
      journal: journal,
    );
  });

  test('repond exactement comme le parseur de regles', () async {
    final CommandProposal proposal = await parser.parse('vendu du sucre');

    expect(proposal.intentId, equals('record_sale'));
    expect(proposal.origin, ProposalOrigin.rules);
    expect(rules.callCount, equals(1));
  });

  test('ecrit le motif de chaque phrase, de la plus recente en tete', () async {
    await parser.parse('premiere phrase');
    await parser.parse('deuxieme phrase');

    expect(journal.events, hasLength(2));
    expect(journal.events.first.utterance, equals('deuxieme phrase'));
    expect(journal.events.last.utterance, equals('premiere phrase'));
    expect(journal.events.first.reason, ParseRouteReason.noCredential);
  });

  test('distingue une clé absente d un cloud volontairement eteint', () async {
    final LocalOnlyParser eteint = LocalOnlyParser(
      local: rules,
      reason: ParseRouteReason.localOnly,
      journal: journal,
    );

    await eteint.parse('phrase');

    expect(journal.events.single.reason, ParseRouteReason.localOnly);
    expect(journal.events.single.reason, isNot(ParseRouteReason.noCredential));
  });

  test('fonctionne sans journal', () {
    final LocalOnlyParser sansJournal = LocalOnlyParser(
      local: rules,
      reason: ParseRouteReason.noCredential,
    );

    expect(() => sansJournal.parse('vendu du sucre'), returnsNormally);
  });
}

final class _CountingRules implements IntentParser {
  int callCount = 0;

  @override
  CommandProposal parse(String raw) {
    callCount += 1;
    return CommandProposal.rules(intentId: 'record_sale', slots: []);
  }
}
