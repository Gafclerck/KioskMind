import 'dart:convert';
import 'dart:io';

import 'package:kiosk_mind/features/voice_assistant/data/catalog/intent_catalog_loader.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/intent_handler.dart';

/// Checks the format and the internal consistency of the frozen test set.
///
/// The set is what the routing metric is measured against, so a mistake in it is
/// a wrong number, not a wrong feature: an expectation naming a product that no
/// longer exists, or a handler argument shape the intent never produces, would
/// make a correct implementation look wrong. Every such defect must be a loud
/// failure, so the tool exits 1 and prints the reason.
///
/// The recordings of the audio set are a human task and are therefore reported
/// as a pending count, never as a failure.
///
/// Usage:
///   dart run tool/validate_golden.dart
const String textCasesPath = 'voice/golden/text_cases.json';
const String audioCasesPath = 'voice/golden/audio_cases.json';
const String catalogFixturePath = 'voice/golden/catalog_fixture.json';

/// Outcomes the decision policy can produce, minus nothing: the golden set has
/// to be able to say that a phrase was meant to be refused.
const Set<String> _outcomes = <String>{
  'EXECUTE',
  'ASK_CONFIRMATION',
  'ASK_CLARIFICATION',
  'REJECT',
};

/// Difficulty tags of the pipeline, section 11.
const Set<String> _tags = <String>{
  'simple',
  'multi_items',
  'numbers_words',
  'numbers_digits',
  'price',
  'ambiguous_product',
  'missing_slot',
  'noise',
  'accent',
  'out_of_domain',
  'hard',
};

/// Slot names a merchant answer may fill. Kept explicit so a typo in a
/// resolution is a failure instead of a silently ignored answer.
const Set<String> _answerSlots = <String>{
  'confirmed',
  'productName',
  'qty',
  'saleRef',
};

/// The runtime sale identifier is not known when the set is written, so the
/// expectations carry a sentinel the evaluation substitutes.
const String lastSaleIdSentinel = r'$lastSaleId';

final RegExp _lineSlot = RegExp(r'^items\[(\d+)\]\.(productName|qty)$');

/// Products the fixture knows, and the ones the voice may name.
final class CatalogView {
  CatalogView(this.activeIds, this.archivedIds);

  factory CatalogView.fromFile(File file) {
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Fixture racine: objet JSON attendu');
    }
    final List<Object?> products =
        (decoded['products'] as List<Object?>?) ?? const [];
    final Set<String> active = <String>{};
    final Set<String> archived = <String>{};
    for (final Object? entry in products) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('Produit: objet JSON attendu');
      }
      final String id = entry['id'] as String? ?? '';
      if (active.contains(id) || archived.contains(id)) {
        throw FormatException('Produit en double: $id');
      }
      if (entry['isArchived'] == true) {
        archived.add(id);
      } else {
        active.add(id);
      }
    }
    return CatalogView(active, archived);
  }

  final Set<String> activeIds;
  final Set<String> archivedIds;
}

/// The verdict of a validation run, so the tool and the test read the same thing.
final class GoldenReport {
  const GoldenReport({
    required this.errors,
    required this.textCases,
    required this.audioCases,
    required this.pendingRecordings,
    required this.demandingCall,
    required this.summary,
  });

  final List<String> errors;
  final int textCases;
  final int audioCases;
  final int pendingRecordings;
  final int demandingCall;
  final String summary;

  bool get isValid => errors.isEmpty;
}

/// Reads and validates one of the two case files.
GoldenReport validateGoldenSet({
  String textPath = textCasesPath,
  String audioPath = audioCasesPath,
  String catalogPath = catalogFixturePath,
  String intentsPath = intentCatalogAsset,
}) {
  final List<String> errors = <String>[];
  final CatalogView catalog = CatalogView.fromFile(File(catalogPath));
  final Set<String> intents = parseIntentCatalog(
    File(intentsPath).readAsStringSync(),
  ).ids.toSet();
  final Set<String> supported = kSupportedIntentIds;

  // The catalog and the ports must agree, or an expectation could name an
  // intent the app does not implement.
  for (final String intent in intents) {
    if (!supported.contains(intent)) {
      errors.add('Intent du catalogue sans port: $intent');
    }
  }

  final Map<String, Object?> text = _read(textPath, errors);
  final Map<String, Object?> audio = _read(audioPath, errors);

  final List<Object?> textList = _cases(text, textPath, errors, catalogPath);
  final List<Object?> audioList = _cases(audio, audioPath, errors, catalogPath);

  final Set<String> utterances = <String>{};
  final Set<String> textIds = <String>{};
  final Set<String> tagsSeen = <String>{};
  int demandingCall = 0;

  for (final Object? entry in textList) {
    if (entry is! Map<String, Object?>) {
      errors.add('Cas texte: objet JSON attendu');
      continue;
    }
    final String id = entry['id'] as String? ?? '';
    if (!textIds.add(id)) {
      errors.add('Identifiant de cas en double: $id');
    }
    final String utterance = entry['utterance'] as String? ?? '';
    if (utterance.trim().isEmpty) {
      errors.add('$id: phrase vide');
    }
    if (!utterances.add(utterance)) {
      errors.add('$id: phrase repetee telle quelle: $utterance');
    }
    final Object? tags = entry['tags'];
    if (tags is! List<Object?> || tags.isEmpty) {
      errors.add('$id: au moins une etiquette de difficulte est requise');
    } else {
      for (final Object? tag in tags) {
        if (tag is! String || !_tags.contains(tag)) {
          errors.add('$id: etiquette inconnue: $tag');
        } else {
          tagsSeen.add(tag);
        }
      }
    }
    if (entry.containsKey('notes') && entry['notes'] is! String) {
      errors.add('$id: notes doit etre une chaine');
    }
    final bool callsHandler = _validateExpectation(
      entry['expected'],
      where: id,
      catalog: catalog,
      intents: intents,
      errors: errors,
    );
    if (callsHandler) {
      demandingCall++;
    }
  }

  for (final String tag in _tags.difference(tagsSeen)) {
    errors.add('Etiquette du pipeline sans aucun cas: $tag');
  }

  // The audio set mirrors text cases, so the two scores cannot drift apart.
  final Map<String, Map<String, Object?>> textById =
      <String, Map<String, Object?>>{
        for (final Object? entry in textList)
          if (entry is Map<String, Object?>) entry['id'] as String: entry,
      };
  final Set<String> audioIds = <String>{};
  final Set<String> speakers = <String>{};
  final Set<String> noises = <String>{};
  for (final Object? entry in audioList) {
    if (entry is! Map<String, Object?>) {
      errors.add('Cas audio: objet JSON attendu');
      continue;
    }
    final String id = entry['id'] as String? ?? '';
    if (!audioIds.add(id)) {
      errors.add('Identifiant de cas audio en double: $id');
    }
    final String source = entry['sourceTextCase'] as String? ?? '';
    final Map<String, Object?>? origin = textById[source];
    if (origin == null) {
      errors.add('$id: cas texte source inconnu: $source');
    } else if (jsonEncode(origin['expected']) !=
        jsonEncode(entry['expected'])) {
      errors.add('$id: attente differente du cas texte $source');
    } else if (entry['groundTruthTranscript'] != origin['utterance']) {
      errors.add('$id: transcription differente du cas texte $source');
    }
    final String file = entry['file'] as String? ?? '';
    if (!file.endsWith('.wav')) {
      errors.add('$id: fichier audio attendu en .wav, obtenu $file');
    }
    final Object? speaker = entry['speaker'];
    if (speaker is! String || speaker.isEmpty) {
      errors.add('$id: locuteur manquant');
    } else {
      speakers.add(speaker);
    }
    final Object? noise = entry['noise'];
    if (noise is! String || noise.isEmpty) {
      errors.add('$id: condition sonore manquante');
    } else {
      noises.add(noise);
    }
  }

  // A single voice would hide a recognition problem, and a single acoustic
  // condition would hide a noise problem.
  if (speakers.length < 2) {
    errors.add('Jeu audio: au moins deux locuteurs sont requis');
  }
  if (noises.length < 2) {
    errors.add('Jeu audio: au moins deux conditions sonores sont requises');
  }

  int pendingRecordings = 0;
  for (final Object? entry in audioList) {
    if (entry is Map<String, Object?> &&
        !File(entry['file'] as String).existsSync()) {
      pendingRecordings++;
    }
  }

  // A set that is mostly questions would pass a pipeline that always asks, so
  // the share of cases demanding a handler call is part of the verdict.
  if (textList.isNotEmpty) {
    final double share = demandingCall / textList.length;
    if (share < 0.5) {
      errors.add(
        'Trop peu de cas exigent un appel de handler '
        '($demandingCall/${textList.length}), le jeu measure la clarification, pas le routage',
      );
    }
  }

  return GoldenReport(
    errors: errors,
    textCases: textList.length,
    audioCases: audioList.length,
    pendingRecordings: pendingRecordings,
    demandingCall: demandingCall,
    summary:
        'texte: $demandingCall/${textList.length} cas exigent un appel, '
        '${tagsSeen.length}/${_tags.length} etiquettes, '
        'audio: ${audioList.length} cas dont $pendingRecordings sans enregistrement',
  );
}

void main(List<String> arguments) {
  final GoldenReport report = validateGoldenSet();
  stdout.writeln(report.summary);
  for (final String error in report.errors) {
    stderr.writeln('ERREUR $error');
  }
  if (!report.isValid) {
    stderr.writeln('${report.errors.length} erreur(s) sur le jeu fige');
    exitCode = 1;
  }
}

Map<String, Object?> _read(String path, List<String> errors) {
  final File file = File(path);
  if (!file.existsSync()) {
    errors.add('Fichier absent: $path');
    return const <String, Object?>{};
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    errors.add('$path: objet JSON attendu a la racine');
    return const <String, Object?>{};
  }
  return decoded;
}

List<Object?> _cases(
  Map<String, Object?> root,
  String path,
  List<String> errors,
  String catalogPath,
) {
  if (root['version'] != 1) {
    errors.add('$path: version 1 attendue, obtenu ${root['version']}');
  }
  if (root['currency'] != 'XOF') {
    errors.add('$path: devise XOF attendue, obtenu ${root['currency']}');
  }
  if (root['catalog'] != catalogPath) {
    errors.add('$path: reference au fixture attendue: $catalogPath');
  }
  final Object? cases = root['cases'];
  if (cases is! List<Object?>) {
    errors.add('$path: liste de cas attendue');
    return const [];
  }
  if (cases.isEmpty) {
    errors.add('$path: aucun cas');
  }
  return cases;
}

/// Validates one expectation and reports whether it demands a handler call.
///
/// A clarification that states the call which must follow it demands one, so a
/// pipeline that always asks cannot score well: it would never reach the call.
bool _validateExpectation(
  Object? node, {
  required String where,
  required CatalogView catalog,
  required Set<String> intents,
  required List<String> errors,
}) {
  if (node is! Map<String, Object?>) {
    errors.add('$where: attente attendue en objet JSON');
    return false;
  }
  final Object? outcome = node['outcome'];
  if (outcome is! String || !_outcomes.contains(outcome)) {
    errors.add('$where: issue inconnue: $outcome');
    return false;
  }
  switch (outcome) {
    case 'REJECT':
      if (node['reason'] is! String) {
        errors.add('$where: un refus doit dire pourquoi');
      }
      for (final String forbidden in <String>[
        'intent',
        'handlerArgs',
        'then',
      ]) {
        if (node.containsKey(forbidden)) {
          errors.add('$where: un refus ne peut pas porter $forbidden');
        }
      }
      return false;
    case 'ASK_CONFIRMATION':
      final bool valid = _validateCall(
        node,
        where: where,
        catalog: catalog,
        intents: intents,
        errors: errors,
      );
      _validateResolution(
        node['resolution'],
        where: '$where/confirmation',
        errors: errors,
      );
      return valid;
    case 'ASK_CLARIFICATION':
      if (node['reason'] is! String) {
        errors.add('$where: une question doit dire pourquoi');
      }
      final Object? then = node['then'];
      if (then == null) {
        return false;
      }
      if (then is! Map<String, Object?>) {
        errors.add('$where/then: objet JSON attendu');
        return false;
      }
      final bool valid = _validateCall(
        then,
        where: '$where/then',
        catalog: catalog,
        intents: intents,
        errors: errors,
        nested: true,
      );
      _validateResolution(
        node['resolution'],
        where: '$where/then',
        errors: errors,
      );
      return valid;
    default:
      return _validateCall(
        node,
        where: where,
        catalog: catalog,
        intents: intents,
        errors: errors,
      );
  }
}

bool _validateCall(
  Map<String, Object?> node, {
  required String where,
  required CatalogView catalog,
  required Set<String> intents,
  required List<String> errors,
  bool nested = false,
}) {
  if (nested) {
    final Object? outcome = node['outcome'];
    if (outcome != 'EXECUTE' && outcome != 'ASK_CONFIRMATION') {
      errors.add('$where: issue d appel attendue, obtenu $outcome');
      return false;
    }
    if (outcome == 'ASK_CONFIRMATION') {
      _validateResolution(node['resolution'], where: where, errors: errors);
    }
  }
  final String intent = node['intent'] as String? ?? '';
  if (!intents.contains(intent)) {
    errors.add('$where: intent absent du catalogue: $intent');
    return false;
  }
  final Object? arguments = node['handlerArgs'];
  if (arguments is! Map<String, Object?>) {
    errors.add('$where: handlerArgs attendu en objet JSON');
    return false;
  }
  switch (intent) {
    case 'record_sale':
    case 'record_restock':
      return _validateLines(
        arguments,
        intent: intent,
        where: where,
        catalog: catalog,
        errors: errors,
      );
    case 'query_stock':
      return _validateProduct(
        arguments['productId'],
        where: where,
        catalog: catalog,
        errors: errors,
      );
    case 'cancel_last_sale':
      final Object? saleId = arguments['saleId'];
      if (saleId != lastSaleIdSentinel) {
        errors.add('$where: saleId attendu, sentinelle $lastSaleIdSentinel');
        return false;
      }
      if (arguments.keys.length != 1) {
        errors.add('$where: cancel_last_sale ne porte que saleId');
        return false;
      }
      return true;
    default:
      errors.add('$where: arguments non valides pour $intent');
      return false;
  }
}

bool _validateLines(
  Map<String, Object?> arguments, {
  required String intent,
  required String where,
  required CatalogView catalog,
  required List<String> errors,
}) {
  if (arguments.keys.length != 1) {
    errors.add('$where: $intent ne porte que items');
    return false;
  }
  final Object? items = arguments['items'];
  if (items is! List<Object?> || items.isEmpty) {
    errors.add('$where: au moins une ligne attendue');
    return false;
  }
  for (final Object? line in items) {
    if (line is! Map<String, Object?>) {
      errors.add('$where: ligne attendue en objet JSON');
      return false;
    }
    if (!_validateProduct(
      line['productId'],
      where: where,
      catalog: catalog,
      errors: errors,
    )) {
      return false;
    }
    final Object? qty = line['qty'];
    if (qty is! num || qty <= 0) {
      errors.add('$where: quantite strictement positive attendue, obtenu $qty');
      return false;
    }
    for (final String key in line.keys) {
      final bool known =
          key == 'productId' ||
          key == 'qty' ||
          (intent == 'record_restock' && key == 'unitCost');
      if (!known) {
        errors.add('$where: argument de ligne inconnu: $key');
        return false;
      }
    }
    final Object? cost = line['unitCost'];
    if (cost != null && (cost is! num || cost <= 0)) {
      errors.add('$where: cout strictement positif attendu, obtenu $cost');
      return false;
    }
  }
  return true;
}

bool _validateProduct(
  Object? productId, {
  required String where,
  required CatalogView catalog,
  required List<String> errors,
}) {
  if (productId is! String) {
    errors.add('$where: productId attendu');
    return false;
  }
  // An archived product is outside the voice vocabulary (model v2, 4.6): an
  // expectation may not ask for a sale the application would refuse.
  if (catalog.archivedIds.contains(productId)) {
    errors.add('$where: produit archive, hors vocabulaire vocal: $productId');
    return false;
  }
  if (!catalog.activeIds.contains(productId)) {
    errors.add('$where: produit inconnu du fixture: $productId');
    return false;
  }
  return true;
}

void _validateResolution(
  Object? node, {
  required String where,
  required List<String> errors,
}) {
  if (node is! List<Object?> || node.isEmpty) {
    errors.add('$where: reponse du commerçant attendue');
    return;
  }
  for (final Object? step in node) {
    if (step is! Map<String, Object?>) {
      errors.add('$where: etape de reponse attendue en objet JSON');
      return;
    }
    final String slot = step['slot'] as String? ?? '';
    if (!_answerSlots.contains(slot) && !_lineSlot.hasMatch(slot)) {
      errors.add('$where: slot inconnu: $slot');
    }
    if (!step.containsKey('value')) {
      errors.add('$where: valeur attendue pour $slot');
    }
  }
}
