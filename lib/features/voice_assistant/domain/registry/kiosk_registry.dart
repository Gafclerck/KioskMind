import '../entities/fact_result.dart';
import 'kiosk_tool_spec.dart';

/// Registry of tools/actions available in the KioskMind assistant.
///
/// Ported from assistantv3 `Registry`:
/// Extensibility port allowing new business actions (sales, restock, stock query,
/// customer debt, alerts) to be plugged in without modifying the engine.
final class KioskRegistry {
  KioskRegistry();

  /// Factory pre-registering all 14 KioskMind assistant tools.
  factory KioskRegistry.withAllKioskTools() {
    final KioskRegistry registry = KioskRegistry();

    registry.register(
      KioskToolSpec(
        name: 'record_sale',
        label: "vente d'un ou plusieurs produits",
        example: 'vends deux savons',
        paramLabels: const <String, String>{
          'items':
              'Liste des articles avec productId, qty et spokenUnitPrice optionnel',
        },
        jsonFormatExample:
            '{"intentId": "record_sale", "items": [{"productId": "<id_catalogue>", "qty": 2.0, "spokenUnitPrice": 500}]}',
        declarationKeywords: const <String>{'vends', 'vente', 'acheter', 'prend'},
        handler: (params) async =>
            const FactResult(operation: 'record_sale', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'record_restock',
        label: 'approvisionnement ou entrée en stock',
        example: 'ajoute 10 sacs de riz',
        paramLabels: const <String, String>{
          'items':
              'Liste des articles avec productId, qty et spokenUnitCost optionnel',
        },
        jsonFormatExample:
            '{"intentId": "record_restock", "items": [{"productId": "<id_catalogue>", "qty": 5.0, "spokenUnitCost": 400}]}',
        declarationKeywords: const <String>{
          'ajoute',
          'entree',
          'recu',
          'stocker',
          'reappro',
          'reassort',
          'achat',
          'livraison',
          'restock',
        },
        handler: (params) async =>
            const FactResult(operation: 'record_restock', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_stock',
        label: "demande d'information sur le stock restant",
        example: 'combien de sucre en stock',
        paramLabels: const <String, String>{
          'productId': 'Identifiant du produit dans le catalogue',
        },
        jsonFormatExample:
            '{"intentId": "query_stock", "productId": "<id_catalogue>"}',
        declarationKeywords: const <String>{'stock', 'combien', 'reste'},
        handler: (params) async =>
            const FactResult(operation: 'query_stock', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'cancel_last_sale',
        label: 'annulation de la dernière vente',
        example: 'annule la vente',
        jsonFormatExample: '{"intentId": "cancel_last_sale"}',
        declarationKeywords: const <String>{'annuler', 'annule', 'retour'},
        handler: (params) async =>
            const FactResult(operation: 'cancel_last_sale', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_daily_stats',
        label: "bilan du jour, chiffre d'affaires, total des ventes du jour",
        example: 'quel est le bilan du jour',
        paramLabels: const <String, String>{
          'date': 'Date cible (défaut: today)',
        },
        jsonFormatExample:
            '{"intentId": "query_daily_stats", "date": "today"}',
        declarationKeywords: const <String>{
          'bilan',
          'chiffre',
          'affaires',
          'point',
          'total',
          'journee',
        },
        handler: (params) async =>
            const FactResult(operation: 'query_daily_stats', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_low_stock',
        label: 'alerte sur les produits en rupture ou stock faible',
        example: 'quels sont les produits en rupture',
        paramLabels: const <String, String>{
          'level': 'Niveau de stock (out_of_stock ou low_stock)',
        },
        jsonFormatExample:
            '{"intentId": "query_low_stock", "level": "out_of_stock"}',
        declarationKeywords: const <String>{
          'rupture',
          'epuise',
          'manque',
          'faible',
          'vide',
        },
        handler: (params) async =>
            const FactResult(operation: 'query_low_stock', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_product_price',
        label: "demande du prix de vente ou d'achat d'un produit",
        example: 'combien coûte le savon',
        paramLabels: const <String, String>{
          'productId': 'Identifiant du produit dans le catalogue',
        },
        jsonFormatExample:
            '{"intentId": "query_product_price", "productId": "<id_catalogue>"}',
        declarationKeywords: const <String>{'prix', 'coute', 'combien', 'tarif'},
        handler: (params) async =>
            const FactResult(operation: 'query_product_price', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'record_stock_out',
        label: 'perte, casse, péremption, don ou sortie manuelle de stock',
        example: 'deux laits sont périmés',
        paramLabels: const <String, String>{
          'productId': 'Identifiant du produit',
          'qty': 'Quantité sortie',
          'reason': 'Raison (breakage, expired, loss, personal_use)',
        },
        jsonFormatExample:
            '{"intentId": "record_stock_out", "productId": "<id_catalogue>", "qty": 2.0, "reason": "breakage"}',
        declarationKeywords: const <String>{
          'perte',
          'casse',
          'perime',
          'abime',
          'jete',
          'gaspille',
          'sortie',
        },
        handler: (params) async =>
            const FactResult(operation: 'record_stock_out', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'navigate_to_page',
        label:
            'navigation vers un écran (dashboard, stock, sales_history, profile, export, create_sale, add_product)',
        example: 'va dans le stock',
        paramLabels: const <String, String>{
          'destination': 'Écran de destination',
        },
        jsonFormatExample:
            '{"intentId": "navigate_to_page", "destination": "stock"}',
        declarationKeywords: const <String>{
          'affiche',
          'ouvre',
          'va',
          'montre',
          'ecran',
          'page',
        },
        handler: (params) async =>
            const FactResult(operation: 'navigate_to_page', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'export_sales_report',
        label:
            "génération et partage d'un rapport de ventes (format: pdf ou csv)",
        example: 'exporte les ventes en pdf',
        paramLabels: const <String, String>{
          'format': 'pdf ou csv',
          'period': 'day, week, month',
        },
        jsonFormatExample:
            '{"intentId": "export_sales_report", "format": "pdf", "period": "day"}',
        declarationKeywords: const <String>{
          'exporte',
          'partage',
          'rapport',
          'pdf',
          'csv',
          'excel',
        },
        handler: (params) async =>
            const FactResult(operation: 'export_sales_report', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'create_product',
        label: "création d'un nouvel article dans le catalogue",
        example: 'crée le produit savon omo à 500 francs',
        paramLabels: const <String, String>{
          'name': 'Nom du produit',
          'price': 'Prix de vente',
          'purchasePrice': "Prix d'achat optionnel",
          'initialQty': 'Quantité initiale optionnelle',
        },
        jsonFormatExample:
            '{"intentId": "create_product", "name": "Savon Omo", "price": 500, "purchasePrice": 350, "initialQty": 20}',
        declarationKeywords: const <String>{
          'cree',
          'nouveau',
          'ajouter',
          'produit',
          'article',
        },
        handler: (params) async =>
            const FactResult(operation: 'create_product', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'update_product_price',
        label: "mise à jour du prix d'un produit existant",
        example: 'change le prix du sucre à 700 francs',
        paramLabels: const <String, String>{
          'productId': 'Identifiant du produit dans le catalogue',
          'newPrice': 'Nouveau prix de vente',
        },
        jsonFormatExample:
            '{"intentId": "update_product_price", "productId": "<id_catalogue>", "newPrice": 700}',
        declarationKeywords: const <String>{
          'change',
          'modifie',
          'nouveau',
          'prix',
          'augmente',
          'baisse',
        },
        handler: (params) async =>
            const FactResult(operation: 'update_product_price', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_sales_history',
        label: 'historique des dernières ventes',
        example: 'quelles sont les dernières ventes',
        paramLabels: const <String, String>{
          'limit': 'Nombre de ventes à retourner (défaut: 5)',
        },
        jsonFormatExample:
            '{"intentId": "query_sales_history", "limit": 5}',
        declarationKeywords: const <String>{
          'dernieres',
          'historique',
          'ventes',
          'precedentes',
        },
        handler: (params) async =>
            const FactResult(operation: 'query_sales_history', data: {}),
      ),
    );

    registry.register(
      KioskToolSpec(
        name: 'query_business_info',
        label: 'informations générales sur la boutique',
        example: 'donne-moi les infos de la boutique',
        jsonFormatExample: '{"intentId": "query_business_info"}',
        declarationKeywords: const <String>{
          'infos',
          'boutique',
          'magasin',
          'kiosk',
          'statistiques',
        },
        handler: (params) async =>
            const FactResult(operation: 'query_business_info', data: {}),
      ),
    );

    return registry;
  }

  final Map<String, KioskToolSpec> _tools = <String, KioskToolSpec>{};

  /// Registers a tool spec into the registry.
  /// Throws [StateError] if a tool with the same name is already registered.
  void register(KioskToolSpec spec) {
    if (_tools.containsKey(spec.name)) {
      throw StateError('Outil déjà enregistré dans le registre: ${spec.name}');
    }
    _tools[spec.name] = spec;
  }

  /// Gets a tool by its unique name.
  KioskToolSpec? get(String name) => _tools[name];

  /// Returns all registered tools.
  List<KioskToolSpec> allTools() =>
      List<KioskToolSpec>.unmodifiable(_tools.values);

  /// Converts all registered tools into a standard Gemini Function Calling declarations list.
  List<Map<String, dynamic>> toGeminiTools() => _tools.values
      .map((KioskToolSpec s) => s.toFunctionDeclaration())
      .toList();

  /// Converts all registered tools into a concise prompt description for LLM system instructions.
  String toPromptDescription() {
    final StringBuffer buffer = StringBuffer();
    for (final KioskToolSpec spec in _tools.values) {
      buffer.writeln('- \'${spec.name}\' : ${spec.label}.');
    }
    return buffer.toString().trim();
  }

  /// Generates the formatted JSON response examples section for LLM system prompts.
  String toResponseFormatPrompt() {
    final StringBuffer buffer = StringBuffer();
    for (final KioskToolSpec spec in _tools.values) {
      buffer.writeln('- Pour \'${spec.name}\' :');
      buffer.writeln('  ${spec.formatExample()}');
    }
    return buffer.toString().trim();
  }

  /// Builds a complete grounded system prompt for LLM intent interpretation.
  String buildSystemPrompt() {
    return "Tu es l'assistant de caisse de KioskMind pour les commerçants d'Afrique de l'Ouest.\n"
        "Analyse la phrase prononcée par le commerçant et identifie son intention parmi :\n"
        "${toPromptDescription()}\n\n"
        "RÈGLE D'ANCRAGE STRICTE (D5) :\n"
        "Pour les intentions manipulant des produits existants ('record_sale', 'record_restock', 'query_stock', 'query_product_price', 'record_stock_out', 'update_product_price'), tu dois OBLIGATOIREMENT et UNIQUEMENT utiliser les 'id' des produits qui figurent explicitement dans le catalogue fourni.\n"
        "N'invente JAMAIS d'identifiant de produit qui n'est pas dans le catalogue. Pour 'create_product', utilise le nom prononcé dans le champ 'name'.\n\n"
        "FORMAT DE RÉPONSE OBLIGATOIRE EN JSON PUR :\n"
        "${toResponseFormatPrompt()}";
  }

  /// Fallback detector (DeclarationSpec from assistantv3):
  /// If the NLU fails to match, inspects utterance tokens for declared tool keywords.
  KioskToolSpec? detectDeclaration(String utterance) {
    final String clean = utterance.toLowerCase();
    for (final KioskToolSpec spec in _tools.values) {
      if (spec.declarationKeywords.isEmpty) continue;
      for (final String keyword in spec.declarationKeywords) {
        if (clean.contains(keyword.toLowerCase())) {
          return spec;
        }
      }
    }
    return null;
  }

  /// Clears the registry (useful for testing and hot reload).
  void clear() {
    _tools.clear();
  }
}
