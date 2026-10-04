import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/parsers/direct_gemini_caller.dart';

void main() {
  group('DirectGeminiCaller', () {
    test('returns empty map immediately when apiKey is empty', () async {
      int postCount = 0;
      final caller = DirectGeminiCaller(
        apiKey: '',
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

    test('formats prompt with catalog and parses Gemini JSON response', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;

      final caller = DirectGeminiCaller(
        apiKey: 'test-api-key-123',
        httpPoster:
            (uri, headers, body, {timeout = const Duration(seconds: 2)}) async {
              capturedUri = uri;
              capturedBody = body;
              return {
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'text':
                              '{"intentId": "record_sale", "items": [{"productId": "p_sucre", "qty": 2.0}]}',
                        },
                      ],
                    },
                  },
                ],
              };
            },
      );

      final result = await caller.call('interpretUtterance', {
        'utterance': 'vends deux sucres',
        'catalog': [
          {'id': 'p_sucre', 'name': 'Sucre', 'price': 500},
        ],
      });

      expect(capturedUri.toString(), contains('key=test-api-key-123'));
      expect(capturedUri.toString(), contains('gemini-1.5-flash'));
      expect(capturedBody, isNotNull);
      expect(
        capturedBody!['generationConfig']['response_mime_type'],
        equals('application/json'),
      );

      expect(result['intentId'], equals('record_sale'));
      final items = result['items'] as List<dynamic>;
      expect(items.first['productId'], equals('p_sucre'));
      expect(items.first['qty'], equals(2.0));
    });

    test(
      'returns empty map gracefully on HTTP failure or network exception',
      () async {
        final caller = DirectGeminiCaller(
          apiKey: 'test-api-key-123',
          httpPoster:
              (
                uri,
                headers,
                body, {
                timeout = const Duration(seconds: 2),
              }) async {
                throw Exception('Connection timeout or reset');
              },
        );

        final result = await caller.call('interpretUtterance', {
          'utterance': 'vends deux sucres',
          'catalog': [],
        });

        expect(result, isEmpty);
      },
    );

    test(
      'returns empty map gracefully when candidate text is not valid JSON',
      () async {
        final caller = DirectGeminiCaller(
          apiKey: 'test-api-key-123',
          httpPoster:
              (
                uri,
                headers,
                body, {
                timeout = const Duration(seconds: 2),
              }) async {
                return {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': 'Non-json raw response from model'},
                        ],
                      },
                    },
                  ],
                };
              },
        );

        final result = await caller.call('interpretUtterance', {
          'utterance': 'bonjour',
          'catalog': [],
        });

        expect(result, isEmpty);
      },
    );
  });
}
