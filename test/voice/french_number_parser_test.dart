import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';

void main() {
  const FrenchNumberParser parser = FrenchNumberParser();

  /// The value of the number starting at the first token of [tokens].
  double? value(List<String> tokens) => parser.readAt(tokens, 0)?.value;

  group('chiffres', () {
    test('entiers', () {
      expect(value(<String>['2']), 2);
      expect(value(<String>['30']), 30);
      expect(value(<String>['1000']), 1000);
      expect(value(<String>['0']), 0);
    });

    test('decimaux avec point ou virgule', () {
      expect(value(<String>['2.5']), 2.5);
      expect(value(<String>['4.5']), 4.5);
    });

    test('le nombre s arrete au premier mot', () {
      expect(value(<String>['2', 'savon']), 2);
      expect(value(<String>['12', 'biere']), 12);
    });
  });

  group('noms de nombres', () {
    test('unites', () {
      for (final MapEntry<String, int> entry in _units.entries) {
        expect(
          value(<String>[entry.key]),
          entry.value.toDouble(),
          reason: entry.key,
        );
      }
    });

    test('dizaines', () {
      expect(value(<String>['vingt']), 20);
      expect(value(<String>['trente']), 30);
      expect(value(<String>['quarante']), 40);
      expect(value(<String>['cinquante']), 50);
      expect(value(<String>['soixante']), 60);
    });

    test('composes additifs', () {
      expect(value(<String>['dix', 'sept']), 17);
      expect(value(<String>['dix', 'huit']), 18);
      expect(value(<String>['vingt', 'cinq']), 25);
      expect(value(<String>['soixante', 'quinze']), 75);
      expect(value(<String>['soixante', 'dix']), 70);
    });

    test('soixante et onze', () {
      expect(value(<String>['soixante', 'et', 'une']), 61);
      expect(value(<String>['soixante', 'et', 'onze']), 71);
    });

    test('un seul mot', () {
      expect(value(<String>['un']), 1);
      expect(value(<String>['une']), 1);
      expect(value(<String>['vingts']), 20);
      expect(value(<String>['cents']), 100);
    });
  });

  group('multiplicateurs', () {
    test('cent', () {
      expect(value(<String>['cent']), 100);
      expect(value(<String>['trois', 'cents']), 300);
      expect(value(<String>['sept', 'cents']), 700);
    });

    test('vingt', () {
      expect(value(<String>['quatre', 'vingt']), 80);
      expect(value(<String>['quatre', 'vingts']), 80);
      expect(value(<String>['quatre', 'vingt', 'dix']), 90);
      expect(value(<String>['quatre', 'vingt', 'dix', 'sept']), 97);
    });

    test('quatrevingt ecrit en un seul mot', () {
      expect(value(<String>['quatrevingt']), 80);
      expect(value(<String>['quatrevingts']), 80);
      expect(value(<String>['cent', 'quatrevingts']), 180);
    });

    test('mille', () {
      expect(value(<String>['mille']), 1000);
      expect(value(<String>['quatre', 'mille']), 4000);
      expect(value(<String>['six', 'mille']), 6000);
    });

    test('mille suivi de cent', () {
      expect(value(<String>['quatre', 'mille', 'huit', 'cents']), 4800);
    });

    test('montants du catalogue', () {
      expect(value(<String>['cent']), 100);
      expect(value(<String>['deux', 'cent', 'cinquante']), 250);
      expect(value(<String>['trois', 'cents']), 300);
      expect(value(<String>['cinq', 'cent', 'soixante']), 560);
      expect(value(<String>['cent', 'quatre', 'vingt', 'dix']), 190);
      expect(value(<String>['soixante', 'quinze']), 75);
      expect(value(<String>['deux', 'cent', 'quarante']), 240);
    });

    test('grande quantite', () {
      expect(value(<String>['deux', 'cent', 'soixante', 'quinze']), 275);
    });
  });

  group('fractions', () {
    test('un demi vaut un dixieme de plus', () {
      expect(value(<String>['un', 'demi']), 0.5);
      expect(value(<String>['une', 'demi']), 0.5);
    });

    test('demi seul', () {
      expect(value(<String>['demi']), 0.5);
    });

    test('un demi sac consomme les deux mots', () {
      expect(
        parser.readAt(<String>['un', 'demi', 'sac', 'riz'], 0)?.consumed,
        2,
      );
    });
  });

  group('ce qui n est pas un nombre', () {
    test('un mot inconnu', () {
      expect(value(<String>['sucre']), isNull);
      expect(value(<String>['savon']), isNull);
      expect(value(<String>['riz', 'parfume']), isNull);
    });

    test('une suite vide', () {
      expect(value(<String>[]), isNull);
    });

    test('legerement hors borne', () {
      expect(parser.readAt(<String>['sucre', '2'], 0), isNull);
      expect(parser.readAt(<String>['2', 'sucre'], 5), isNull);
    });

    test('ne confonde pas un mot proche', () {
      expect(value(<String>['sept']), 7);
      expect(value(<String>['savon']), isNull);
    });
  });

  test('conserve le nombre de jetons consommes', () {
    expect(parser.readAt(<String>['cinq', 'sachets'], 0)?.consumed, 1);
    expect(
      parser.readAt(<String>[
        'quatre',
        'mille',
        'huit',
        'cents',
        'riz',
      ], 0)?.consumed,
      4,
    );
  });
}

const Map<String, int> _units = <String, int>{
  'zero': 0,
  'un': 1,
  'une': 1,
  'deux': 2,
  'trois': 3,
  'quatre': 4,
  'cinq': 5,
  'six': 6,
  'sept': 7,
  'huit': 8,
  'neuf': 9,
  'dix': 10,
  'onze': 11,
  'douze': 12,
  'treize': 13,
  'quatorze': 14,
  'quinze': 15,
  'seize': 16,
};
