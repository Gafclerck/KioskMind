import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/catalog_fixture_loader.dart'
    show parseCatalogFixture;
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/commands/voice_bindings.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/product_name_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/formulator/offline_natural_formulator.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/call_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/mock/mock_voice_handlers.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/dialog/dialog_manager.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/fact_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/slot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_id_factory.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_registry.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_application.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_reading.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/command_validator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/decision_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/execute_command.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/handle_utterance.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/usecases/undo_last_command.dart';
import 'package:kiosk_mind/features/voice_assistant/presentation/state/voice_outcome.dart';

import 'fake_clock.dart';
import 'rule_parser_harness.dart';

class _MultiProposalParser implements IntentParser {
  _MultiProposalParser(this.proposal);
  final CommandProposal proposal;

  @override
  Future<CommandProposal> parse(String raw) async => proposal;
}

class _SequentialIds implements CommandIdFactory {
  int _next = 1;
  @override
  String next() => 'cmd-${_next++}';
}

void main() {
  group('Multi-Action Turn Execution (ported from assistantv3)', () {
    test(
      'executes primary and secondary commands and consolidates facts',
      () async {
        final RuleParserHarness harness = RuleParserHarness();
        final FakeClock clock = FakeClock(DateTime(2026, 3, 14, 8));
        final InMemoryCallJournal journal = InMemoryCallJournal();
        final InMemoryProductCatalog catalog = InMemoryProductCatalog(
          parseCatalogFixture(File(catalogFixtureAsset).readAsStringSync()),
        );
        final productSucre = catalog.productById('p_sucre')!;

        // 1. Primary command: record_sale (2 sucres)
        // 2. Secondary command: query_stock (sucre)
        const CommandProposal secondaryProposal = CommandProposal.rules(
          intentId: 'query_stock',
          slots: <Slot>[Slot(name: 'productId', value: 'p_sucre')],
        );

        final CommandProposal primaryProposal = CommandProposal.rules(
          intentId: 'record_sale',
          slots: <Slot>[
            Slot(
              name: 'items',
              value: <ItemMention>[
                ItemMention(product: productSucre, qty: 2.0),
              ],
            ),
          ],
          nextProposals: <CommandProposal>[secondaryProposal],
        );

        final DialogManager dialog = DialogManager(
          config: harness.config,
          clock: clock,
        );
        final VoiceHandlers handlers = buildMockVoiceHandlers(
          catalog: catalog,
          journal: journal,
        );
        final UndoLastCommand undo = UndoLastCommand(
          handlers: handlers,
          dialog: dialog,
          clock: clock,
          ids: _SequentialIds(),
        );

        final HandleUtterance handle = HandleUtterance(
          parser: _MultiProposalParser(primaryProposal),
          validator: CommandValidator(
            config: harness.config,
            intents: harness.intents,
          ),
          policy: DecisionPolicy(catalog: harness.intents),
          executor: ExecuteCommand(
            registry: IntentRegistry(
              buildVoiceBindings(handlers: handlers, undo: undo),
            ),
            dialog: dialog,
            clock: clock,
            ids: _SequentialIds(),
          ),
          dialog: dialog,
          answers: AnswerApplication(
            intents: harness.intents,
            resolver: ProductNameResolver(
              resolver: harness.resolver,
              normalizer: harness.normalizer,
            ),
          ),
          reading: AnswerReading(
            normalizer: harness.normalizer,
            numbers: const FrenchNumberParser(),
            products: ProductNameResolver(
              resolver: harness.resolver,
              normalizer: harness.normalizer,
            ),
          ),
        );

        final VoiceTurn turn = await handle.run(
          'vends deux sucres et donne moi le stock',
        );

        expect(turn.executed, isTrue);
        expect(turn.secondaryExecutions.length, 1);
        expect(turn.secondaryExecutions.first.isExecuted, isTrue);

        // Verify that both commands reached the handlers!
        expect(journal.calls.length, 2);
        expect(journal.calls[0].intentId, 'record_sale');
        expect(journal.calls[1].intentId, 'query_stock');

        // Now verify that the formulator consolidates both facts into a single natural sentence!
        final List<FactResult> allFacts = <FactResult>[
          outcomeOf(turn.execution!)!.toFactResult(),
          outcomeOf(turn.secondaryExecutions.first)!.toFactResult(),
        ];

        const OfflineNaturalFormulator formulator = OfflineNaturalFormulator();
        final String speech = formulator.formatSync(
          userUtterance: 'vends deux sucres et donne moi le stock',
          facts: allFacts,
          staticFallback: '',
        );

        expect(speech, contains('Sucre'));
        expect(speech, contains('Vente enregistrée'));
        expect(speech, contains('Et'));
        expect(speech, contains('magasin'));
      },
    );
  });
}
