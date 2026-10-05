import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
    HttpJsonPoster? httpPoster,
  }) : _httpPoster = httpPoster ?? _defaultHttpPoster;

  final String apiKey;
  final String model;
  final Duration timeout;
  final HttpJsonPoster _httpPoster;

  static const String _systemPrompt =
      "Tu es l'assistant de caisse et de gestion de KioskMind pour les commerçants d'Afrique de l'Ouest.\n"
      "Analyse la phrase prononcée par le commerçant et identifie son intention parmi :\n"
      "- 'record_sale' : vente d'un ou plusieurs produits.\n"
      "- 'record_restock' : approvisionnement ou entrée en stock.\n"
      "- 'query_stock' : demande d'information sur le stock restant.\n"
      "- 'cancel_last_sale' : annulation de la dernière vente.\n"
      "- 'query_daily_stats' : bilan du jour, chiffre d'affaires, total des ventes du jour.\n"
      "- 'query_low_stock' : alerte sur les produits en rupture ou stock faible.\n"
      "- 'query_product_price' : demande du prix de vente ou d'achat d'un produit.\n"
      "- 'record_stock_out' : perte, casse, péremption, don ou sortie manuelle de stock.\n"
      "- 'navigate_to_page' : navigation vers un écran (dashboard, stock, sales_history, profile, export, create_sale, add_product).\n"
      "- 'export_sales_report' : génération et partage d'un rapport de ventes (format: pdf ou csv).\n"
      "- 'create_product' : création d'un nouvel article dans le catalogue.\n"
      "- 'update_product_price' : mise à jour du prix d'un produit existant.\n"
      "- 'query_sales_history' : historique des dernières ventes.\n"
      "- 'query_business_info' : informations générales sur la boutique.\n\n"
      "RÈGLE D'ANCRAGE STRICTE (D5) :\n"
      "Pour les intentions manipulant des produits existants ('record_sale', 'record_restock', 'query_stock', 'query_product_price', 'record_stock_out', 'update_product_price'), tu dois OBLIGATOIREMENT et UNIQUEMENT utiliser les 'id' des produits qui figurent explicitement dans le catalogue fourni.\n"
      "N'invente JAMAIS d'identifiant de produit qui n'est pas dans le catalogue. Pour 'create_product', utilise le nom prononcé dans le champ 'name'.\n\n"
      "FORMAT DE RÉPONSE OBLIGATOIRE EN JSON PUR :\n"
      "- Pour une vente :\n"
      "  {\"intentId\": \"record_sale\", \"items\": [{\"productId\": \"<id_catalogue>\", \"qty\": 2.0, \"spokenUnitPrice\": 500}]}\n"
      "- Pour un réapprovisionnement :\n"
      "  {\"intentId\": \"record_restock\", \"items\": [{\"productId\": \"<id_catalogue>\", \"qty\": 5.0, \"spokenUnitCost\": 400}]}\n"
      "- Pour une question de stock :\n"
      "  {\"intentId\": \"query_stock\", \"productId\": \"<id_catalogue>\"}\n"
      "- Pour une annulation :\n"
      "  {\"intentId\": \"cancel_last_sale\"}\n"
      "- Pour le chiffre d'affaires / bilan du jour :\n"
      "  {\"intentId\": \"query_daily_stats\", \"date\": \"today\"}\n"
      "- Pour les produits en rupture / alertes stock :\n"
      "  {\"intentId\": \"query_low_stock\", \"level\": \"out_of_stock\"}\n"
      "- Pour le prix d'un produit :\n"
      "  {\"intentId\": \"query_product_price\", \"productId\": \"<id_catalogue>\"}\n"
      "- Pour une perte / casse / sortie de stock :\n"
      "  {\"intentId\": \"record_stock_out\", \"productId\": \"<id_catalogue>\", \"qty\": 2.0, \"reason\": \"breakage\"}\n"
      "- Pour naviguer vers un écran :\n"
      "  {\"intentId\": \"navigate_to_page\", \"destination\": \"stock\"}\n"
      "- Pour exporter un rapport :\n"
      "  {\"intentId\": \"export_sales_report\", \"format\": \"pdf\", \"period\": \"day\"}\n"
      "- Pour créer un nouveau produit :\n"
      "  {\"intentId\": \"create_product\", \"name\": \"Savon Omo\", \"price\": 500, \"purchasePrice\": 350, \"initialQty\": 20}\n"
      "- Pour changer le prix d'un produit :\n"
      "  {\"intentId\": \"update_product_price\", \"productId\": \"<id_catalogue>\", \"newPrice\": 700}\n"
      "- Pour les dernières ventes :\n"
      "  {\"intentId\": \"query_sales_history\", \"limit\": 5}\n"
      "- Pour les infos de la boutique :\n"
      "  {\"intentId\": \"query_business_info\"}";

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
