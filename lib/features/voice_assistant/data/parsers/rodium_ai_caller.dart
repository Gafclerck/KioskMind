import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'direct_gemini_caller.dart';

/// Direct caller to Rodium AI OpenAI-compatible API gateway for Cloud NLU interpretation.
///
/// Designed to conform to [CloudFunctionCaller] so it can be passed directly to
/// [RemoteCloudIntentParser].
///
/// Features:
/// - Connects to Rodium AI OpenAI-compatible endpoint (`/v1/chat/completions`).
/// - Prompts Gemini models (default: `google/gemini-1.5-flash`) via Rodium AI gateway.
/// - Enforces Decision D5 catalog grounding and pure JSON output.
/// - Sanitizes markdown code fences and returns [Map<String, dynamic>].
/// - Handles HTTP errors, network timeouts, and non-200 responses gracefully.
final class RodiumAiCaller {
  RodiumAiCaller({
    required this.apiKey,
    this.baseUrl = 'https://api.rodiumai.io/v1',
    this.model = 'google/gemini-1.5-flash',
    this.timeout = const Duration(milliseconds: 2000),
    HttpJsonPoster? httpPoster,
  }) : _httpPoster = httpPoster ?? _defaultHttpPoster;

  final String apiKey;
  final String baseUrl;
  final String model;
  final Duration timeout;
  final HttpJsonPoster _httpPoster;

  static const String _systemPrompt =
      "Tu es l'assistant de caisse de KioskMind pour les commerçants d'Afrique de l'Ouest.\n"
      "Analyse la phrase prononcée par le commerçant et identifie son intention parmi :\n"
      "- 'record_sale' : vente d'un ou plusieurs produits.\n"
      "- 'record_restock' : approvisionnement ou entrée en stock.\n"
      "- 'query_stock' : demande d'information sur le stock restant.\n"
      "- 'cancel_last_sale' : annulation de la dernière vente.\n\n"
      "RÈGLE D'ANCRAGE STRICTE (D5) :\n"
      "Tu dois OBLIGATOIREMENT et UNIQUEMENT utiliser les 'id' des produits qui figurent explicitement dans le catalogue fourni.\n"
      "N'invente JAMAIS d'identifiant de produit qui n'est pas dans le catalogue.\n\n"
      "FORMAT DE RÉPONSE OBLIGATOIRE EN JSON PUR :\n"
      "- Pour une vente :\n"
      "  {\"intentId\": \"record_sale\", \"items\": [{\"productId\": \"<id_catalogue>\", \"qty\": 2.0, \"spokenUnitPrice\": 500}]}\n"
      "- Pour un réapprovisionnement :\n"
      "  {\"intentId\": \"record_restock\", \"items\": [{\"productId\": \"<id_catalogue>\", \"qty\": 5.0, \"spokenUnitCost\": 400}]}\n"
      "- Pour une question de stock :\n"
      "  {\"intentId\": \"query_stock\", \"productId\": \"<id_catalogue>\"}\n"
      "- Pour une annulation :\n"
      "  {\"intentId\": \"cancel_last_sale\"}";

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
        <String, String>{'role': 'system', 'content': _systemPrompt},
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
            '[RodiumAiCaller] HTTP ${response.statusCode}: $responseBody',
          );
        }
      }
      return const <String, dynamic>{};
    } finally {
      client.close();
    }
  }
}
