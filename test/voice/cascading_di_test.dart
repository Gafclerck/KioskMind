import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/diagnostics/in_memory_parse_outcome_journal.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/parse_route.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/cascading_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/local_only_parser.dart';

ProductSnapshot _product(
  String id, {
  required String name,
  double price = 500,
}) {
  return ProductSnapshot(
    id: id,
    name: name,
    aliases: const <String>[],
    unit: 'PIECE',
    price: price,
    purchasePrice: null,
    stock: 10,
    alertThreshold: 0,
    averageDailyQty: 0,
    isArchived: false,
  );
}

final class _StubCloudParser implements CloudIntentParser {
  _StubCloudParser({this.proposal});

  CommandProposal? proposal;
  int callCount = 0;

  @override
  Future<CommandProposal?> parse(String raw) async {
    callCount += 1;
    return proposal;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryProductCatalog catalog;

  setUp(() {
    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      _product('p_sucre', name: 'Sucre', price: 500),
    ]);
  });

  group('Cascading DI Wiring', () {
    test(
      'defaults to LocalOnlyParser when voiceEnableCloud is false',
      () async {
        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceUseMocksProvider.overrideWithValue(true),
            voiceEnableCloudProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        final parser = await container.read(voiceParserProvider.future);

        expect(parser, isA<LocalOnlyParser>());
        expect((parser as LocalOnlyParser).reason, ParseRouteReason.localOnly);
      },
    );

    test(
      'says noCredential instead of reaching the network without a key',
      () async {
        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceUseMocksProvider.overrideWithValue(true),
            voiceEnableCloudProvider.overrideWithValue(true),
            voiceRodiumApiKeyProvider.overrideWithValue(''),
            voiceGeminiApiKeyProvider.overrideWithValue(''),
          ],
        );
        addTearDown(container.dispose);

        final parser = await container.read(voiceParserProvider.future);

        expect(parser, isA<LocalOnlyParser>());
        expect(
          (parser as LocalOnlyParser).reason,
          ParseRouteReason.noCredential,
        );

        // Without a key the parser never touches the network, so the cloud is
        // never paid for on a command the rules can answer at startup.
        await parser.parse('vendu deux sucres');
      },
    );

    test(
      'records the reason in the journal so a silent device is explainable',
      () async {
        final journal = InMemoryParseOutcomeJournal();

        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceUseMocksProvider.overrideWithValue(true),
            voiceEnableCloudProvider.overrideWithValue(true),
            voiceRodiumApiKeyProvider.overrideWithValue(''),
            voiceGeminiApiKeyProvider.overrideWithValue(''),
            voiceParseOutcomeJournalProvider.overrideWithValue(journal),
          ],
        );
        addTearDown(container.dispose);

        final parser = await container.read(voiceParserProvider.future);
        await parser.parse('quel est mon stock');

        expect(journal.events, hasLength(1));
        expect(journal.events.single.reason, ParseRouteReason.noCredential);
        expect(journal.events.single.utterance, equals('quel est mon stock'));
      },
    );

    test(
      'uses CascadingParser when cloud is on and a key is present',
      () async {
        final stubCloud = _StubCloudParser();

        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceUseMocksProvider.overrideWithValue(true),
            voiceEnableCloudProvider.overrideWithValue(true),
            voiceRodiumApiKeyProvider.overrideWithValue('rd_sk_test_123'),
            voiceCloudIntentParserProvider.overrideWith(
              (ref) async => stubCloud,
            ),
          ],
        );
        addTearDown(container.dispose);

        final parser = await container.read(voiceParserProvider.future);

        expect(parser, isA<CascadingParser>());
      },
    );

    test(
      'HandleUtterance delegates through cascade and uses cloud proposal',
      () async {
        final stubCloud = _StubCloudParser(
          proposal: const CommandProposal(
            intentId: 'record_sale',
            slots: [],
            doubts: [],
            origin: ProposalOrigin.languageModel,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceUseMocksProvider.overrideWithValue(true),
            voiceEnableCloudProvider.overrideWithValue(true),
            voiceRodiumApiKeyProvider.overrideWithValue('rd_sk_test_123'),
            voiceCloudIntentParserProvider.overrideWith(
              (ref) async => stubCloud,
            ),
          ],
        );
        addTearDown(container.dispose);

        final turn = await container.read(voiceHandleUtteranceProvider.future);
        final result = await turn.run('vendu deux sucres');

        expect(stubCloud.callCount, equals(1));
        expect(
          result.decision.outcome,
          equals(DecisionOutcome.executeWithUndo),
        );
      },
    );

    test('wires RemoteCloudIntentParser when gemini apiKey is set', () async {
      final container = ProviderContainer(
        overrides: [
          voiceMockCatalogProvider.overrideWith((ref) async => catalog),
          voiceUseMocksProvider.overrideWithValue(true),
          voiceGeminiApiKeyProvider.overrideWithValue('dummy-api-key'),
        ],
      );
      addTearDown(container.dispose);

      final cloudParser = await container.read(
        voiceCloudIntentParserProvider.future,
      );
      expect(cloudParser, isNotNull);
    });

    test('wires RemoteCloudIntentParser when rodium apiKey is set', () async {
      final container = ProviderContainer(
        overrides: [
          voiceMockCatalogProvider.overrideWith((ref) async => catalog),
          voiceUseMocksProvider.overrideWithValue(true),
          voiceRodiumApiKeyProvider.overrideWithValue('rd_sk_test_123'),
        ],
      );
      addTearDown(container.dispose);

      final cloudParser = await container.read(
        voiceCloudIntentParserProvider.future,
      );
      expect(cloudParser, isNotNull);
    });

    test('auto-detects Rodium AI when gemini apiKey has rd_ prefix', () async {
      final container = ProviderContainer(
        overrides: [
          voiceMockCatalogProvider.overrideWith((ref) async => catalog),
          voiceUseMocksProvider.overrideWithValue(true),
          voiceGeminiApiKeyProvider.overrideWithValue('rd_sk_auto_detect_456'),
        ],
      );
      addTearDown(container.dispose);

      final cloudParser = await container.read(
        voiceCloudIntentParserProvider.future,
      );
      expect(cloudParser, isNotNull);
    });
  });
}
