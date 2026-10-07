import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/rodium_ai_caller.dart';

void main() {
  group('RodiumAiCaller', () {
    test('returns empty map immediately when apiKey is empty', () async {
      int postCount = 0;
      final caller = RodiumAiCaller(
        apiKey: '',
        systemPrompt: 'PROMPT_DE_TEST',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 2)}) async {
              postCount++;
              return <String, dynamic>{};
            },
      );

      final result = await caller.call('interpretUtterance', {
        'utterance': 'vends du sucre',
        'catalog': [],
      });

      expect(result, isEmpty);
      expect(postCount, equals(0));
    });

    test(
      'formats OpenAI-compatible payload and parses Rodium choices response',
      () async {
        Uri? capturedUri;
        Map<String, String>? capturedHeaders;
        Map<String, dynamic>? capturedBody;

        final caller = RodiumAiCaller(
          apiKey: 'rd_sk_test_12345',
          model: 'google/gemini-1.5-flash',
          systemPrompt: 'PROMPT_DE_TEST',
          httpPoster:
              (
                uri,
                headers,
                body, {
                timeout = const Duration(seconds: 2),
              }) async {
                capturedUri = uri;
                capturedHeaders = headers;
                capturedBody = body;
                return {
                  'id': 'chatcmpl-rodium-123',
                  'choices': [
                    {
                      'index': 0,
                      'message': {
                        'role': 'assistant',
                        'content':
                            '{"intentId": "record_sale", "items": [{"productId": "p_sucre", "qty": 3.0}]}',
                      },
                    },
                  ],
                };
              },
        );

        final result = await caller.call('interpretUtterance', {
          'utterance': 'vends trois sucres',
          'catalog': [
            {'id': 'p_sucre', 'name': 'Sucre', 'price': 500},
          ],
        });

        expect(
          capturedUri.toString(),
          equals('https://api.rodiumai.io/v1/chat/completions'),
        );
        expect(
          capturedHeaders?['Authorization'],
          equals('Bearer rd_sk_test_12345'),
        );
        expect(capturedHeaders?['Content-Type'], equals('application/json'));
        expect(capturedBody?['model'], equals('google/gemini-1.5-flash'));
        expect(
          capturedBody?['response_format']?['type'],
          equals('json_object'),
        );

        final messages = capturedBody?['messages'] as List<dynamic>;
        expect(messages.length, equals(2));
        expect(messages[0]['role'], equals('system'));
        expect(messages[1]['role'], equals('user'));
        expect(messages[1]['content'], contains('vends trois sucres'));

        expect(result['intentId'], equals('record_sale'));
        final items = result['items'] as List<dynamic>;
        expect(items.first['productId'], equals('p_sucre'));
        expect(items.first['qty'], equals(3.0));
      },
    );

    test('strips markdown code fences from choices content', () async {
      final caller = RodiumAiCaller(
        apiKey: 'rd_sk_test_12345',
        systemPrompt: 'PROMPT_DE_TEST',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 2)}) async {
              return {
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content':
                          '```json\n{"intentId": "query_stock", "productId": "p_riz"}\n```',
                    },
                  },
                ],
              };
            },
      );

      final result = await caller.call('interpretUtterance', {
        'utterance': 'combien de riz reste-t-il',
        'catalog': [
          {'id': 'p_riz', 'name': 'Riz', 'price': 4000},
        ],
      });

      expect(result['intentId'], equals('query_stock'));
      expect(result['productId'], equals('p_riz'));
    });

    test(
      'returns empty map gracefully on network failure or exception',
      () async {
        final caller = RodiumAiCaller(
          apiKey: 'rd_sk_test_12345',
          systemPrompt: 'PROMPT_DE_TEST',
          httpPoster:
              (
                uri,
                headers,
                body, {
                timeout = const Duration(seconds: 2),
              }) async {
                throw Exception('Connection refused or timeout');
              },
        );

        final result = await caller.call('interpretUtterance', {
          'utterance': 'vends du sucre',
          'catalog': [],
        });

        expect(result, isEmpty);
      },
    );

    test('respects custom baseUrl and model', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;

      final caller = RodiumAiCaller(
        apiKey: 'rd_sk_custom',
        baseUrl: 'https://custom-gateway.local/v1',
        model: 'rodiumai/smart',
        systemPrompt: 'PROMPT_DE_TEST',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 2)}) async {
              capturedUri = uri;
              capturedBody = body;
              return {
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content': '{"intentId": "cancel_last_sale"}',
                    },
                  },
                ],
              };
            },
      );

      final result = await caller.call('interpretUtterance', {
        'utterance': 'annule la vente',
        'catalog': [],
      });

      expect(
        capturedUri.toString(),
        equals('https://custom-gateway.local/v1/chat/completions'),
      );
      expect(capturedBody?['model'], equals('rodiumai/smart'));
      expect(result['intentId'], equals('cancel_last_sale'));
    });

    test('passes custom dynamic systemPrompt into messages payload', () async {
      Map<String, dynamic>? capturedBody;

      final caller = RodiumAiCaller(
        apiKey: 'rd_sk_custom',
        systemPrompt: 'CUSTOM_SYSTEM_PROMPT_FROM_RODIUM',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 2)}) async {
              capturedBody = body;
              return {
                'choices': [
                  {
                    'message': {
                      'role': 'assistant',
                      'content': '{"intentId": "custom_intent"}',
                    },
                  },
                ],
              };
            },
      );

      await caller.call('interpretUtterance', {
        'utterance': 'test',
        'catalog': [],
      });

      expect(capturedBody, isNotNull);
      final messages = capturedBody!['messages'] as List<dynamic>;
      expect(messages[0]['role'], equals('system'));
      expect(messages[0]['content'], equals('CUSTOM_SYSTEM_PROMPT_FROM_RODIUM'));
    });
  });
}
