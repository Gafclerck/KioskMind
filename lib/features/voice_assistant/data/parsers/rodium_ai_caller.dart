import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloud_call_failure.dart';
import 'direct_gemini_caller.dart';

/// Direct caller to Rodium AI OpenAI-compatible API gateway for Cloud NLU interpretation.
///
/// Designed to conform to [CloudFunctionCaller] so it can be passed directly to
/// [RemoteCloudIntentParser].
///
/// Features:
/// - Connects to Rodium AI OpenAI-compatible endpoint (`/v1/chat/completions`).
/// - Prompts Gemini models (default: `google/gemini-2.5-flash`) via Rodium AI gateway.
/// - Enforces Decision D5 catalog grounding and pure JSON output.
/// - Sanitizes markdown code fences and returns [Map<String, dynamic>].
/// - Handles HTTP errors, network timeouts, and non-200 responses gracefully.
final class RodiumAiCaller {
  RodiumAiCaller({
    required this.apiKey,
    required this.systemPrompt,
    this.baseUrl = 'https://api.rodiumai.io/v1',
    this.model = 'google/gemini-2.5-flash',
    this.timeout = const Duration(milliseconds: 2000),
    HttpJsonPoster? httpPoster,
  }) : _httpPoster = httpPoster ?? _defaultHttpPoster;

  final String apiKey;
  final String baseUrl;
  final String model;
  final Duration timeout;

  /// What the model is told the shop can do, built from the catalog by
  /// [KioskRegistry.buildSystemPrompt]. Required rather than defaulted: a caller
  /// that forgot it would otherwise reach the network with a prompt describing a
  /// different list of commands than the app has, and nothing would say so.
  final String systemPrompt;

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

    final Uri uri = Uri.parse('$baseUrl/chat/completions');

    final Map<String, dynamic> requestBody = <String, dynamic>{
      'model': model,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': systemPrompt},
        <String, String>{
          'role': 'user',
          'content':
              'Catalogue disponible :\n${jsonEncode(catalog)}\n\n'
              'Phrase prononcée par le commerçant :\n"$utterance"',
        },
      ],
      'temperature': 0.1,
      'response_format': <String, dynamic>{'type': 'json_object'},
    };

    try {
      final Map<String, dynamic> response = await _httpPoster(
        uri,
        <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        requestBody,
        timeout: timeout,
      );

      final List<dynamic>? choices = response['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return const <String, dynamic>{};
      }

      final dynamic firstChoice = choices.first;
      if (firstChoice is! Map) return const <String, dynamic>{};

      final dynamic message = firstChoice['message'];
      if (message is! Map) return const <String, dynamic>{};

      final String? jsonText = message['content'] as String?;
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
    } on CloudCallFailure {
      // A refused key, an exhausted quota and a server error are reported as
      // themselves. Returning an empty answer here is what made all three look like
      // a model that had nothing to say.
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RodiumAiCaller] Error: $e');
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
    final http.Response response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const <String, dynamic>{};
    }
    throw CloudCallFailure.fromResponse(
      'Rodium AI',
      response.statusCode,
      response.body,
    );
  }
}
