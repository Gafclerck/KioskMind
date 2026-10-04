import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rule_based_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/di/voice_dependencies.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/command_proposal.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/decision_outcome.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/cloud_intent_parser.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/connectivity_probe.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/cascading_parser.dart';

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

final class _StubConnectivityProbe implements ConnectivityProbe {
  _StubConnectivityProbe({required this.online});

  bool online;

  @override
  Future<bool> get isOnline => Future<bool>.value(online);
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
      'defaults to RuleBasedParser when voiceEnableCloud is false',
      () async {
        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceEnableCloudProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        final parser = await container.read(voiceParserProvider.future);

        expect(parser, isA<RuleBasedParser>());
      },
    );

    test('uses CascadingParser when voiceEnableCloud is true', () async {
      final stubCloud = _StubCloudParser();
      final stubConnectivity = _StubConnectivityProbe(online: true);

      final container = ProviderContainer(
        overrides: [
          voiceMockCatalogProvider.overrideWith((ref) async => catalog),
          voiceEnableCloudProvider.overrideWithValue(true),
          voiceCloudIntentParserProvider.overrideWith((ref) async => stubCloud),
          voiceConnectivityProbeProvider.overrideWithValue(stubConnectivity),
        ],
      );
      addTearDown(container.dispose);

      final parser = await container.read(voiceParserProvider.future);

      expect(parser, isA<CascadingParser>());
    });

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
        final stubConnectivity = _StubConnectivityProbe(online: true);

        final container = ProviderContainer(
          overrides: [
            voiceMockCatalogProvider.overrideWith((ref) async => catalog),
            voiceEnableCloudProvider.overrideWithValue(true),
            voiceCloudIntentParserProvider.overrideWith(
              (ref) async => stubCloud,
            ),
            voiceConnectivityProbeProvider.overrideWithValue(stubConnectivity),
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
          voiceGeminiApiKeyProvider.overrideWithValue('dummy-api-key'),
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
