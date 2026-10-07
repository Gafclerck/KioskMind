import 'package:flutter_test/flutter_test.dart';
import 'package:stt_tts_spike/src/accuracy.dart';

void main() {
  group('la mise en forme avant comparaison', () {
    test('ignore la casse', () {
      // Les nombres convergent vers l'ecriture numerique, seule forme ou les deux
      // cotes d une phrase peuvent se retrouver.
      expect(comparisonWords('Vendu Deux Savon'), <String>[
        'vendu',
        '2',
        'savon',
      ]);
    });

    test('retire les accents', () {
      expect(comparisonWords('RéçU un Lait Concentré'), <String>[
        'recu',
        '1',
        'lait',
        'concentre',
      ]);
    });

    test('traite la ligature oe', () {
      expect(comparisonWords('cœur'), <String>['coeur']);
    });

    test('coupe sur les apostrophes, que le STT espace ou non', () {
      expect(comparisonWords("de l'huile"), <String>['de', 'l', 'huile']);
      expect(comparisonWords("de l huile"), <String>['de', 'l', 'huile']);
    });

    test('transforme la ponctuation en separateur', () {
      expect(comparisonWords('vendu deux savon, et un lait.'), <String>[
        'vendu',
        '2',
        'savon',
        'et',
        '1',
        'lait',
      ]);
    });

    test('accepte les deux écritures d un nombre', () {
      expect(
        comparisonWords('vendu 2 savon'),
        comparisonWords('vendu deux savon'),
      );
    });

    test(
      'conserve les nombres de plusieurs mots, hors de portee du comparateur',
      () {
        // Le parseur de nombres francais arrive en 1a. Le spike ne pretend pas le
        // remplacer: "cent cinquante" reste deux jetons que le STT peut rendre
        // autrement, et la phrase est signalee comme la moins bonne du jeu.
        expect(
          comparisonWords('a 150 le kilo'),
          isNot(comparisonWords('a cent cinquante le kilo')),
        );
      },
    );

    test('renvoie une liste vide pour une phrase vide', () {
      expect(comparisonWords(''), isEmpty);
      expect(comparisonWords('   '), isEmpty);
      expect(comparisonWords('!!!'), isEmpty);
    });
  });

  group('le taux d erreur', () {
    test('vaut zero sur une transcription identique', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'vendu deux savon',
        heard: 'vendu deux savon',
      );

      expect(rate.errors, 0);
      expect(rate.ratio, 0);
      expect(rate.referenceWords, 3);
    });

    test('compte une substitution par mot change', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'vendu deux savon',
        heard: 'vendu deux shampoing',
      );

      expect(rate.errors, 1);
      expect(rate.ratio, closeTo(1 / 3, 1e-9));
    });

    test('compte une insertion', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'vendu un lait',
        heard: 'vendu encore un lait',
      );

      expect(rate.errors, 1);
    });

    test('compte une suppression', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'vendu un litre de lait',
        heard: 'vendu un lait',
      );

      expect(rate.errors, 2);
    });

    test('ne recompte pas une difference de ponctuation', () {
      expect(
        wordErrorRate(
          reference: 'annule, la vente',
          heard: 'annule la vente',
        ).errors,
        0,
      );
    });

    test('ne recompte pas une difference d accent', () {
      expect(
        wordErrorRate(
          reference: 'lait concentré',
          heard: 'lait concentre',
        ).errors,
        0,
      );
    });

    test('traite une transcription vide comme la totalite des mots perdus', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'vendu deux savon',
        heard: '',
      );

      expect(rate.errors, 3);
      expect(rate.ratio, 1);
    });

    test('ne divise pas par zero quand la reference est vide', () {
      final WordErrorRate rate = wordErrorRate(reference: '', heard: '');

      expect(rate.ratio, 0, reason: 'rien attendu, rien entendu');
    });

    test(
      'compte tout comme faux quand la reference est vide et que quelque chose est entendu',
      () {
        final WordErrorRate rate = wordErrorRate(
          reference: '',
          heard: 'bonjour',
        );

        expect(rate.ratio, 1);
      },
    );

    test('se lit en pourcentage lisible', () {
      final WordErrorRate rate = wordErrorRate(
        reference: 'a b c d',
        heard: 'a b c e',
      );

      expect(rate.toString(), contains('25.0%'));
    });
  });

  group('le taux litteral, lui, ne pardonne rien', () {
    test('compte une difference d accent', () {
      expect(
        wordErrorRateOfWords(
          literalWords('concentré'),
          literalWords('concentre'),
        ).errors,
        1,
      );
    });

    test('compte une difference d apostrophe', () {
      // "l'huile" tient en un jeton litteral, "l huile" en deux: le taux litteral
      // voit la difference, la ou le taux plié la pardonne.
      expect(
        wordErrorRateOfWords(
          literalWords("l'huile"),
          literalWords('l huile'),
        ).errors,
        2,
      );
    });
  });

  group('la distance', () {
    test('vaut zero sur deux listes vides', () {
      expect(wordErrorRateOfWords(<String>[], <String>[]).errors, 0);
    });

    test('mesure toute la longueur quand la reference est vide', () {
      expect(wordErrorRateOfWords(<String>[], <String>['a', 'b']).errors, 2);
    });

    test('mesure toute la longueur quand la transcription est vide', () {
      expect(wordErrorRateOfWords(<String>['a', 'b'], <String>[]).errors, 2);
    });
  });
}
