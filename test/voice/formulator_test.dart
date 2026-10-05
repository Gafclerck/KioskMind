import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/formulator/ai_message_formulator.dart';
import 'package:kiosk_mind/features/voice_assistant/data/formulator/cascading_message_formulator.dart';
import 'package:kiosk_mind/features/voice_assistant/data/formulator/offline_natural_formulator.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/fact_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/connectivity_probe.dart';

class _FakeConnectivityProbe implements ConnectivityProbe {
  _FakeConnectivityProbe(this.online);
  final bool online;

  @override
  Future<bool> get isOnline async => online;
}

void main() {
  group('OfflineNaturalFormulator', () {
    const OfflineNaturalFormulator formulator = OfflineNaturalFormulator();

    test('formulates natural sale with single item and total', () async {
      const FactResult saleFact = FactResult(
        operation: 'record_sale',
        data: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'product': 'Riz', 'qty': 2, 'unit': 'sac'},
          ],
          'total': 10000,
        },
      );

      final String result = await formulator.formulate(
        userUtterance: 'vends deux sacs de riz à dix mille',
        facts: [saleFact],
        staticFallback: 'Vente enregistrée.',
      );

      expect(result, contains('Riz'));
      expect(result, contains('dix mille FCFA'));
      expect(result, contains('Vente enregistrée'));
    });

    test('formulates stock query gracefully', () async {
      const FactResult stockFact = FactResult(
        operation: 'query_stock',
        data: <String, dynamic>{
          'product': 'Savon',
          'stock': 12,
          'unit': 'piece',
        },
      );

      final String result = await formulator.formulate(
        userUtterance: 'combien de savon reste-t-il',
        facts: [stockFact],
        staticFallback: 'Stock disponible.',
      );

      expect(result, contains('Savon'));
      expect(result, contains('12'));
    });

    test(
      'combines multiple operations naturally in a single sentence',
      () async {
        const FactResult saleFact = FactResult(
          operation: 'record_sale',
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'product': 'Riz', 'qty': 1},
            ],
            'total': 5000,
          },
        );
        const FactResult stockFact = FactResult(
          operation: 'query_stock',
          data: <String, dynamic>{'product': 'Sucre', 'stock': 8},
        );

        final String result = await formulator.formulate(
          userUtterance: 'vends un riz et dis moi le stock de sucre',
          facts: [saleFact, stockFact],
          staticFallback: 'Operations terminees.',
        );

        expect(result, contains('Vente enregistrée'));
        expect(result, contains('cinq mille FCFA'));
        expect(result, contains('Sucre'));
        expect(result, contains('8'));
        expect(result, contains('Et'));
      },
    );
  });

  group('CascadingMessageFormulator', () {
    test('uses offline natural formulation when offline', () async {
      final OfflineNaturalFormulator offline = const OfflineNaturalFormulator();
      final AiMessageFormulator ai = AiMessageFormulator(
        apiKey: 'test-key',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 1)}) async {
              throw Exception('Should not be called when offline');
            },
      );

      final CascadingMessageFormulator cascading = CascadingMessageFormulator(
        aiFormulator: ai,
        offlineFormulator: offline,
        connectivity: _FakeConnectivityProbe(false),
      );

      const FactResult fact = FactResult(
        operation: 'record_sale',
        data: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'product': 'Lait', 'qty': 3},
          ],
          'total': 3000,
        },
      );

      final String result = await cascading.formulate(
        userUtterance: 'vends 3 laits',
        facts: [fact],
        staticFallback: 'Vente enregistrée.',
      );

      expect(result, contains('Lait'));
      expect(result, contains('trois mille FCFA'));
    });

    test('falls back to offline natural formulation if AI throws', () async {
      final OfflineNaturalFormulator offline = const OfflineNaturalFormulator();
      final AiMessageFormulator ai = AiMessageFormulator(
        apiKey: 'test-key',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 1)}) async {
              throw Exception('Network timeout');
            },
      );

      final CascadingMessageFormulator cascading = CascadingMessageFormulator(
        aiFormulator: ai,
        offlineFormulator: offline,
        connectivity: _FakeConnectivityProbe(true),
      );

      const FactResult fact = FactResult(
        operation: 'record_sale',
        data: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'product': 'Lait', 'qty': 1},
          ],
          'total': 1000,
        },
      );

      final String result = await cascading.formulate(
        userUtterance: 'vends un lait',
        facts: [fact],
        staticFallback: 'Vente enregistrée.',
      );

      expect(result, contains('Lait'));
      expect(result, contains('mille FCFA'));
    });
  });
}
