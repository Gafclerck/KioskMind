import 'dart:convert';

import '../../domain/entities/product_snapshot.dart';

/// Path of the product catalog shipped with the app, declared as an asset.
const String catalogFixtureAsset = 'voice/golden/catalog_fixture.json';

/// Reads the product catalog fixture into snapshots.
///
/// Takes the raw JSON instead of loading the asset itself, so the same code is
/// exercised by unit tests, by `voice_eval` and at runtime. Validation is
/// strict and failures are loud: a broken catalog is a configuration error, not
/// something to paper over with a fallback (see `main.dart`).
List<ProductSnapshot> parseCatalogFixture(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Fixture racine: objet JSON attendu');
  }
  if (_requireInt(decoded, 'version') != 1) {
    throw FormatException(
      'Fixture "version": 1 attendu, obtenu ${decoded['version']}',
    );
  }
  _requireString(decoded, 'currency');

  final Object? rawProducts = decoded['products'];
  if (rawProducts is! List<Object?>) {
    throw const FormatException('Fixture "products": liste attendue');
  }
  if (rawProducts.isEmpty) {
    throw const FormatException('Fixture "products": liste vide');
  }

  return _parseProducts(rawProducts);
}

List<ProductSnapshot> _parseProducts(List<Object?> rawProducts) {
  final List<ProductSnapshot> products = <ProductSnapshot>[];
  final Set<String> seenIds = <String>{};
  for (int index = 0; index < rawProducts.length; index++) {
    final Object? entry = rawProducts[index];
    if (entry is! Map<String, Object?>) {
      throw FormatException('Produit #$index: objet JSON attendu');
    }
    final ProductSnapshot product = _parseProduct(entry, index);
    if (!seenIds.add(product.id)) {
      throw FormatException(
        'Produit #$index: identifiant duplique "${product.id}"',
      );
    }
    products.add(product);
  }
  return products;
}

ProductSnapshot _parseProduct(Map<String, Object?> json, int index) {
  final String id = _requireString(json, 'id');
  if (id.contains('/') || id.isEmpty) {
    throw FormatException(
      'Produit #$index: "id" invalide pour un document Firestore: "$id"',
    );
  }
  final double price = _requireNumber(json, 'price');
  if (price < 0) {
    throw FormatException('Produit #$index ("$id"): "price" negatif');
  }
  final Object? rawAliases = json['aliases'];
  if (rawAliases is! List<Object?>) {
    throw FormatException('Produit #$index ("$id"): "aliases" liste attendue');
  }
  final List<String> aliases = <String>[
    for (final Object? alias in rawAliases)
      _requireNonEmptyString(alias, '$id.aliases'),
  ];

  return ProductSnapshot(
    id: id,
    name: _requireNonEmptyString(json['name'], '$id.name'),
    aliases: aliases,
    unit: _requireNonEmptyString(json['unit'], '$id.unit'),
    price: price,
    purchasePrice: _optionalNumber(json, 'purchasePrice'),
    stock: _requireNumber(json, 'stock'),
    alertThreshold: _requireNumber(json, 'alertThreshold'),
    averageDailyQty: _requireNumber(json, 'averageDailyQty'),
    isArchived: _optionalBool(json, 'isArchived'),
  );
}

String _requireString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('"$key": chaine non vide attendue, obtenu $value');
  }
  return value;
}

String _requireNonEmptyString(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$label: chaine non vide attendue, obtenu $value');
  }
  return value;
}

int _requireInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  if (value is double && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('"$key": entier attendu, obtenu $value');
}

double _requireNumber(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('"$key": nombre attendu, obtenu $value');
}

double? _optionalNumber(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('"$key": nombre attendu, obtenu $value');
}

bool _optionalBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  throw FormatException('"$key": booleen attendu, obtenu $value');
}
