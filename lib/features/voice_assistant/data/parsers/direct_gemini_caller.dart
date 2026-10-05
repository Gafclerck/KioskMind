import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/registry/kiosk_registry.dart';

typedef HttpJsonPoster =
    Future<Map<String, dynamic>> Function(
      Uri uri,
      Map<String, String> headers,
      Map<String, dynamic> body, {
      Duration timeout,
    });

/// Direct caller to Google Gemini API (gemini-1.5-flash) for Cloud NLU interpretation.
///
/// Designed to conform to [CloudFunctionCaller] so it can be passed directly to
/// [RemoteCloudIntentParser].
///
/// Features:
/// - Prompts Gemini 1.5 Flash with the merchant's active catalog and Decision D5 grounding.
/// - Enforces JSON output mode (`response_mime_type: "application/json"`).
/// - Gracefully returns an empty map on any HTTP error, network failure, or timeout.
final class DirectGeminiCaller {
  DirectGeminiCaller({
    required this.apiKey,
    this.model = 'gemini-1.5-flash',
    this.timeout = const Duration(milliseconds: 2000),
    String? systemPrompt,
    HttpJsonPoster? httpPoster,
  }) : _systemPrompt = systemPrompt ??
           KioskRegistry.withAllKioskTools().buildSystemPrompt(),
       _httpPoster = httpPoster ?? _defaultHttpPoster;

  final String apiKey;
  final String model;
  final Duration timeout;
  final String _systemPrompt;
  final HttpJsonPoster _httpPoster;

  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    if (apiKey.isEmpty) {
      return const <String, dynamic>{};
    }

    final String utterance = parameters['utterance'] as String? ?? '';
    final List<dynamic> catalog =
        parameters['catalog'] as List<dynamic>? ?? const <dynamic>[];

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': _systemPrompt},
        ],
      },
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text':
                  'Catalogue disponible :\n${jsonEncode(catalog)}\n\n'
                  'Phrase prononcée par le commerçant :\n"$utterance"',
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'response_mime_type': 'application/json',
        'temperature': 0.1,
      },
    };

    try {
      final Map<String, dynamic> response = await _httpPoster(
        uri,
        <String, String>{'Content-Type': 'application/json'},
        requestBody,
        timeout: timeout,
      );

      final List<dynamic>? candidates =
          response['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return const <String, dynamic>{};
      }

      final dynamic firstCandidate = candidates.first;
      if (firstCandidate is! Map) return const <String, dynamic>{};

      final dynamic content = firstCandidate['content'];
      if (content is! Map) return const <String, dynamic>{};

      final List<dynamic>? parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return const <String, dynamic>{};

      final dynamic firstPart = parts.first;
      if (firstPart is! Map) return const <String, dynamic>{};

      final String? jsonText = firstPart['text'] as String?;
      if (jsonText == null || jsonText.isEmpty) {
        return const <String, dynamic>{};
      }

      String sanitized = jsonText.trim();
      if (sanitized.startsWith('```json')) {
        sanitized = sanitized.substring(7);
      } else if (sanitized.startsWith('```')) {
        sanitized = sanitized.substring(3);
      }
      if (sanitized.endsWith('```')) {
        sanitized = sanitized.substring(0, sanitized.length - 3);
      }
      sanitized = sanitized.trim();

      final dynamic decoded = jsonDecode(sanitized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const <String, dynamic>{};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DirectGeminiCaller] Error: $e');
      }
      return const <String, dynamic>{};
    }
  }

  static Future<Map<String, dynamic>> _defaultHttpPoster(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client
          .postUrl(uri)
          .timeout(timeout);
      headers.forEach(request.headers.set);
      final String jsonBody = jsonEncode(body);
      request.headers.contentType = ContentType.json;
      request.write(jsonBody);

      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final String responseBody = await utf8
          .decodeStream(response)
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '[DirectGeminiCaller] HTTP ${response.statusCode}: $responseBody',
          );
        }
      }
      return const <String, dynamic>{};
    } finally {
      client.close();
    }
  }
}
