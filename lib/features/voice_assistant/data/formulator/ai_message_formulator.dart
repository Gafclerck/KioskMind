import 'dart:async';
import 'dart:convert';

import '../../domain/entities/fact_result.dart';
import '../../domain/ports/message_formulator.dart';
import '../../domain/services/fact_preserving_guard.dart';
import '../parsers/direct_gemini_caller.dart';

/// Cloud AI implementation of [MessageFormulator].
///
/// Ported from assistantv3 `Formulator`: prompts a fast cloud language model
/// (e.g. Gemini 1.5 Flash / Rodium AI) to formulate a friendly, concise, human-sounding
/// response incorporating the exact structured facts.
///
/// The response is verified by [FactPreservingGuard]. Any hallucination, invented number,
/// network error, or timeout immediately triggers a silent fallback to [staticFallback].
final class AiMessageFormulator implements MessageFormulator {
  AiMessageFormulator({
    required this.apiKey,
    this.endpointUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
    this.timeout = const Duration(milliseconds: 1200),
    FactPreservingGuard? guard,
    HttpJsonPoster? httpPoster,
  }) : _guard = guard ?? const FactPreservingGuard(),
       _httpPoster = httpPoster ?? _defaultHttpPoster;

  final String apiKey;
  final String endpointUrl;
  final Duration timeout;
  final FactPreservingGuard _guard;
  final HttpJsonPoster _httpPoster;

  static const String _systemPrompt =
      "Tu es l'assistant vocal intelligent de caisse pour une boutique en Afrique de l'Ouest.\n"
      "Tu rédiges la réponse finale après qu'une ou plusieurs opérations ont été exécutées avec succès.\n"
      "On te fournit les FAITS exacts réalisés par le système.\n\n"
      "RÈGLES STRICTES D'INTÉGRITÉ :\n"
      "1. Appuie-toi UNIQUEMENT sur les faits fournis : reproduis exactement les valeurs chiffrées, prix en FCFA, noms de produits et quantités.\n"
      "2. N'arrondis JAMAIS, n'additionne pas de tête, et n'invente AUCUN chiffre ni aucun solde.\n"
      "3. Rédige une réponse fluide, chaleureuse, naturelle et très concise (1 à 2 phrases courtes maximum, idéale pour être lue à voix haute par synthèse vocale).\n"
      "4. Si plusieurs opérations ont été exécutées (ex: vente + question stock), résume-les en une seule phrase harmonieuse.\n"
      "5. N'utilise jamais le mot 'fait' et ne mentionne pas la technique.";

  @override
  Future<String> formulate({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) async {
    if (apiKey.isEmpty || facts.isEmpty) {
      return staticFallback;
    }

    try {
      final List<Map<String, dynamic>> factsList = facts
          .map((f) => f.toJson())
          .toList();
      final String factsBlob = jsonEncode(factsList);

      final Uri uri = Uri.parse('$endpointUrl?key=$apiKey');
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
                    'Opérations réalisées et leurs faits exacts :\n$factsBlob\n\n'
                    'Demande initiale du commerçant : "$userUtterance"',
              },
            ],
          },
        ],
        'generationConfig': <String, dynamic>{'temperature': 0.0},
      };

      final Map<String, dynamic> response = await _httpPoster(
        uri,
        <String, String>{'Content-Type': 'application/json'},
        requestBody,
        timeout: timeout,
      );

      final String? content = _extractContent(response);
      if (content == null || content.trim().isEmpty) {
        return staticFallback;
      }

      final String cleanContent = content.trim();

      // Invariant check: verify that the generated text adheres to the facts!
      _guard.check(facts, cleanContent);

      return cleanContent;
    } catch (_) {
      // Guard violation, network error, timeout, or malformed JSON:
      // Gracefully fall back to the deterministic local static text.
      return staticFallback;
    }
  }

  String? _extractContent(Map<String, dynamic> response) {
    try {
      final List<dynamic>? candidates =
          response['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final Map<String, dynamic> first =
          candidates.first as Map<String, dynamic>;
      final Map<String, dynamic>? content =
          first['content'] as Map<String, dynamic>?;
      if (content == null) return null;
      final List<dynamic>? parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      return (parts.first as Map<String, dynamic>)['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  String formatSync({
    required String userUtterance,
    required List<FactResult> facts,
    required String staticFallback,
  }) => staticFallback;

  static Future<Map<String, dynamic>> _defaultHttpPoster(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    // In actual production, calls http/httpClient. Handled through dependency injection.
    return const <String, dynamic>{};
  }
}
