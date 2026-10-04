import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/fact_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/policies/confirmation_policy.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/policies/precheck_verdict.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/registry/kiosk_registry.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/registry/kiosk_tool_spec.dart';

void main() {
  group('KioskRegistry & Policies', () {
    late KioskRegistry registry;

    setUp(() {
      registry = KioskRegistry();
    });

    test('registers and retrieves tool specs without collision', () {
      final KioskToolSpec spec = KioskToolSpec(
        name: 'record_sale',
        label: 'Enregistrer une vente',
        example: 'vends 2 savons',
        handler: (params) async =>
            const FactResult(operation: 'record_sale', data: {}),
      );

      registry.register(spec);
      expect(registry.get('record_sale'), equals(spec));
      expect(registry.allTools().length, equals(1));
    });

    test('rejects duplicate tool registration', () {
      final KioskToolSpec spec = KioskToolSpec(
        name: 'record_sale',
        label: 'Vente',
        example: 'vends 1 riz',
        handler: (params) async =>
            const FactResult(operation: 'record_sale', data: {}),
      );

      registry.register(spec);
      expect(() => registry.register(spec), throwsStateError);
    });

    test('ThresholdConfirmation requires confirmation above limit', () {
      const ThresholdConfirmation policy = ThresholdConfirmation(
        amountField: 'amount',
        limit: 50000,
      );

      expect(policy.requires({'amount': 25000}), isFalse);
      expect(policy.requires({'amount': 60000}), isTrue);
    });

    test('detects declaration fallback from keywords', () {
      final KioskToolSpec spec = KioskToolSpec(
        name: 'query_stock',
        label: 'Consulter le stock',
        example: 'combien de riz en stock',
        declarationKeywords: {'stock', 'reste'},
        handler: (params) async =>
            const FactResult(operation: 'query_stock', data: {}),
      );

      registry.register(spec);

      final KioskToolSpec? detected = registry.detectDeclaration(
        'est ce quil en reste ?',
      );
      expect(detected, isNotNull);
      expect(detected!.name, equals('query_stock'));
    });

    test('PrecheckVerdict supports ask with choices', () {
      final PrecheckVerdict verdict = PrecheckVerdict.ask(
        field: 'product_id',
        question: 'Quel sucre désirez-vous ?',
        choices: [
          {'id': '1', 'name': 'Sucre roux'},
          {'id': '2', 'name': 'Sucre blanc'},
        ],
      );

      expect(verdict.toString(), contains('Quel sucre'));
    });
  });
}
