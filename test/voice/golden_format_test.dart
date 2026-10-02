import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_golden.dart';

/// The golden set is what the routing metric is measured against, so a silent
/// defect in it is a wrong number rather than a wrong feature. These tests
/// check two things: the set as committed is valid, and the validator really
/// does catch the defects it claims to catch.
void main() {
  group('le jeu fige tel que committe', () {
    late GoldenReport report;

    setUpAll(() {
      report = validateGoldenSet();
    });

    test('passe toutes les verifications de format', () {
      expect(report.errors, isEmpty, reason: report.errors.join('\n'));
      expect(report.isValid, isTrue);
    });

    test('couvre les 11 etiquettes de difficulte du pipeline', () {
      expect(report.summary, contains('11/11 etiquettes'));
    });

    test('atteint la taille de texte demandee par le pipeline', () {
      // Un jeu de 100 cas laisse environ 7 points d'incertitude sur un
      // pourcentage; le pipeline en demande au moins 200.
      expect(report.textCases, greaterThanOrEqualTo(200));
    });

    test('atteint la taille audio demandee par le pipeline', () {
      expect(report.audioCases, greaterThanOrEqualTo(40));
    });

    test('une majorite des cas exige un appel de handler', () {
      // Un jeu surtout compose de questions passerait avec un pipeline qui
      // demande toujours, sans jamais router.
      expect(report.demandingCall, greaterThan(report.textCases ~/ 2));
    });

    test(
      'signale les enregistrements audio comme en attente, sans echouer',
      () {
        expect(report.pendingRecordings, report.audioCases);
        expect(report.isValid, isTrue);
      },
    );
  });

  group('le validateur detecte les defauts', () {
    late Directory workspace;
    late Map<String, Object?> text;
    late Map<String, Object?> audio;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('voice_golden_test');
      text = _load(textCasesPath);
      audio = _load(audioCasesPath);
    });

    tearDown(() {
      workspace.deleteSync(recursive: true);
    });

    test('une phrase repetee telle quelle', () {
      final List<Object?> cases = text['cases']! as List<Object?>;
      final Map<String, Object?> first = cases.first! as Map<String, Object?>;
      cases.add(<String, Object?>{
        'id': 't999',
        'utterance': first['utterance'],
        'expected': first['expected'],
        'tags': <String>['simple'],
        'notes': '',
      });

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('phrase repetee'),
      );
    });

    test('un identifiant de cas en double', () {
      final List<Object?> cases = text['cases']! as List<Object?>;
      final Map<String, Object?> first = cases.first! as Map<String, Object?>;
      final Map<String, Object?> copy = Map<String, Object?>.of(first)
        ..['utterance'] = 'vendu deux savon et demi';
      cases.add(copy);

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('en double'),
      );
    });

    test('une etiquette hors du vocabulaire du pipeline', () {
      final Map<String, Object?> first = _cases(text).first;
      first['tags'] = <String>['mystery'];

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('etiquette inconnue'),
      );
    });

    test('une etiquette du pipeline oubliee', () {
      final List<Object?> cases = _cases(text);
      for (final Object? entry in cases) {
        (entry! as Map<String, Object?>)['tags'] = <String>['simple'];
      }

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('sans aucun cas'),
      );
    });

    test('une issue inconnue', () {
      _cases(text).first['expected'] = <String, Object?>{'outcome': 'MAYBE'};

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('issue inconnue'),
      );
    });

    test('un produit absent du fixture', () {
      _setProduct(_cases(text).first, 'p_does_not_exist');

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('produit inconnu'),
      );
    });

    test('un produit archive, hors vocabulaire vocal', () {
      _setProduct(_cases(text).first, 'p_vieux_lait');

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('hors vocabulaire vocal'),
      );
    });

    test('une quantite nulle', () {
      _firstLineOf(_cases(text).first)['qty'] = 0;

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('strictement positive'),
      );
    });

    test('une quantite ecrite en texte', () {
      _firstLineOf(_cases(text).first)['qty'] = 'deux';

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('strictement positive'),
      );
    });

    test('un cout sur une ligne de vente', () {
      // Le prix annonce est un signal de doute, jamais un argument d'appel
      // (contrat A7): l'attendu doit donc le refuser.
      _firstLineOf(_cases(text).first)['unitCost'] = 75;

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('argument de ligne inconnu'),
      );
    });

    test('un argument que l intent ne produit pas', () {
      _argumentsOf(_expectedOf(_cases(text).first))['discount'] = 10;

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('ne porte que items'),
      );
    });

    test('un intent absent du catalogue', () {
      _cases(text).first['expected'] = <String, Object?>{
        'outcome': 'EXECUTE',
        'intent': 'open_the_cash_drawer',
        'handlerArgs': <String, Object?>{'items': <Object?>[]},
      };

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('absent du catalogue'),
      );
    });

    test('un refus qui porte quand meme un appel', () {
      _cases(text).first['expected'] = <String, Object?>{
        'outcome': 'REJECT',
        'reason': 'hors perimetre',
        'intent': 'record_sale',
        'handlerArgs': <String, Object?>{},
      };

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('ne peut pas porter intent'),
      );
    });

    test('un refus qui ne dit pas pourquoi', () {
      _cases(text).first['expected'] = <String, Object?>{'outcome': 'REJECT'};

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('doit dire pourquoi'),
      );
    });

    test('un slot de reponse inconnu', () {
      final Map<String, Object?> expected = _firstClarification(text);
      expected['resolution'] = <Object?>[
        <String, Object?>{'slot': 'items[0].weight', 'value': 2},
      ];

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('slot inconnu'),
      );
    });

    test('une reponse sans valeur', () {
      final Map<String, Object?> expected = _firstClarification(text);
      expected['resolution'] = <Object?>[
        <String, Object?>{'slot': 'items[0].qty'},
      ];

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('valeur attendue'),
      );
    });

    test('un jeu vide', () {
      text['cases'] = <Object?>[];

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('aucun cas'),
      );
    });

    test('une version inconnue', () {
      text['version'] = 2;

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('version 1 attendue'),
      );
    });

    test('une devise inconnue', () {
      text['currency'] = 'EUR';

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('devise XOF attendue'),
      );
    });

    test('un cas audio dont l attente a derive du cas texte', () {
      final Map<String, Object?> first = _cases(audio).first;
      first['expected'] = <String, Object?>{
        'outcome': 'REJECT',
        'reason': 'derivee',
      };

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('attente differente'),
      );
    });

    test('un cas audio dont la transcription a derive du cas texte', () {
      _cases(audio).first['groundTruthTranscript'] = 'autre chose';

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('transcription differente'),
      );
    });

    test('un cas audio qui pointe un cas texte inconnu', () {
      _cases(audio).first['sourceTextCase'] = 't999';

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('cas texte source inconnu'),
      );
    });

    test('un fichier audio qui n est pas un wav', () {
      _cases(audio).first['file'] = 'voice/golden/audio/a001.mp3';

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('.wav'),
      );
    });

    test('un seul locuteur', () {
      for (final Object? entry in _cases(audio)) {
        (entry! as Map<String, Object?>)['speaker'] = 'homme_35';
      }

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('deux locuteurs'),
      );
    });

    test('une seule condition sonore', () {
      for (final Object? entry in _cases(audio)) {
        (entry! as Map<String, Object?>)['noise'] = 'silence';
      }

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains('deux conditions sonores'),
      );
    });

    test('un jeu qui ne mesure que la clarification', () {
      // Un pipeline qui demande toujours doit tomber a zero: c'est le piege que
      // le ratio de cas executables est la fait empecher.
      for (final Object? entry in _cases(text)) {
        (entry! as Map<String, Object?>)['expected'] = <String, Object?>{
          'outcome': 'ASK_CLARIFICATION',
          'reason': 'produit ambigu',
        };
      }

      expect(
        _validate(workspace, text, audio).errors.join('\n'),
        contains(
          'Trop peu de cas exigent un appel de handler (0/269), '
          'le jeu measure la clarification, pas le routage',
        ),
      );
    });
  });

  group('les enregistrements audio', () {
    test(
      'sont comptes, pas exiges, tant que le humaine ne les a pas produits',
      () {
        final GoldenReport report = validateGoldenSet();

        expect(report.pendingRecordings, greaterThan(0));
        expect(
          report.isValid,
          isTrue,
          reason: 'les .wav sont une tache humaine',
        );
      },
    );
  });
}

Map<String, Object?> _load(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
}

List<Map<String, Object?>> _cases(Map<String, Object?> root) {
  return (root['cases']! as List<Object?>).cast<Map<String, Object?>>();
}

Map<String, Object?> _expectedOf(Map<String, Object?> testCase) {
  return testCase['expected']! as Map<String, Object?>;
}

/// Les arguments d'appel sont soit directs, soit dans l'appel attendu apres
/// une question. Le `!` est justifie: une forme inattendue doit faire echouer le
/// test, pas passer silencieusement.
Map<String, Object?> _argumentsOf(Map<String, Object?> expected) {
  final Object? arguments =
      expected['handlerArgs'] ??
      (expected['then']! as Map<String, Object?>)['handlerArgs'];
  return arguments! as Map<String, Object?>;
}

Map<String, Object?> _firstLineOf(Map<String, Object?> testCase) {
  final List<Object?> items =
      _argumentsOf(_expectedOf(testCase))['items']! as List<Object?>;
  return items.first! as Map<String, Object?>;
}

Map<String, Object?> _firstClarification(Map<String, Object?> root) {
  return _cases(root)
      .map(
        (Map<String, Object?> entry) =>
            entry['expected']! as Map<String, Object?>,
      )
      .firstWhere(
        (Map<String, Object?> expected) =>
            expected['outcome'] == 'ASK_CLARIFICATION' &&
            expected.containsKey('then'),
      );
}

void _setProduct(Map<String, Object?> testCase, String productId) {
  final Map<String, Object?> arguments = _argumentsOf(_expectedOf(testCase));
  if (arguments['items'] is List<Object?>) {
    _firstLineOf(testCase)['productId'] = productId;
  } else {
    arguments['productId'] = productId;
  }
}

/// Le fixture est lu, jamais ecrit: le garder a sa place evite de casser la
/// reference que chaque fichier de cas porte. Les cas mutes sont ecrits dans un
/// repertoire de travail, donc le jeu committe n'est jamais touche.
GoldenReport _validate(
  Directory workspace,
  Map<String, Object?> text,
  Map<String, Object?> audio,
) {
  final String textPath = workspace.uri.resolve('text_cases.json').toFilePath();
  final String audioPath = workspace.uri
      .resolve('audio_cases.json')
      .toFilePath();
  File(textPath).writeAsStringSync(jsonEncode(text));
  File(audioPath).writeAsStringSync(jsonEncode(audio));

  return validateGoldenSet(textPath: textPath, audioPath: audioPath);
}
