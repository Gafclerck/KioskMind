import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/line_extractor.dart';

import 'rule_parser_harness.dart';

void main() {
  final RuleParserHarness harness = RuleParserHarness();
  final LineExtractor lines = harness.lines;

  /// First product span in [tokens].
  ProductSpan firstProduct(List<String> tokens) {
    for (int index = 0; index < tokens.length; index++) {
      final ProductSpan? span = harness.resolver.matchAt(tokens, index);
      if (span != null) {
        return span;
      }
    }
    throw StateError('aucun produit dans cette phrase');
  }

  /// Index of the first product name in [tokens].
  int firstName(List<String> tokens) => firstProduct(tokens).start;

  /// Reads the line of the first product name of [raw].
  LineReading read(String raw) {
    final List<String> tokens = harness.tokensOf(raw);
    final ProductSpan span = firstProduct(tokens);
    return lines.read(tokens, span.start, productLength: span.length);
  }

  double? quantityOf(String raw) => read(raw).quantity;
  double? amountOf(String raw) => read(raw).amount;

  group('quantite', () {
    test('un nombre juste avant le nom', () {
      expect(quantityOf('vendu deux savon'), 2);
    });

    test('un nombre juste apres le nom (syntaxe comptoir)', () {
      expect(quantityOf('vendu savon deux'), 2);
      expect(quantityOf('vendu savon 2'), 2);
      expect(quantityOf('vendu savon trois morceaux'), 3);
      expect(quantityOf('vendu riz 5 kilos'), 5);
      expect(quantityOf('vendu savon de menage quatre'), 4);
    });

    test('un article partitif sans nombre ne donne pas de quantite', () {
      expect(quantityOf('vendu du sucre'), isNull);
    });

    test('un nombre suivi d une unite', () {
      expect(quantityOf('cinq sachets de sucre'), 5);
      expect(quantityOf("un litre d'huile"), 1);
      expect(quantityOf('2PACK de pate'), 2);
    });

    test('la lecture la plus longue qui finit au bon endroit', () {
      // "cents" seul vaut 100, "trois cents" vaut 300.
      expect(quantityOf('reçu trois cents pates'), 300);
      expect(quantityOf('vendu quatre-vingt-dix cafe'), 90);
      expect(quantityOf('vendu deux cent soixante quinze biere'), 275);
    });

    test('"un demi" vaut un demi', () {
      expect(quantityOf('un demi sac de riz'), 0.5);
    });

    test('un nombre en chiffres', () {
      expect(quantityOf('vendu 2.5 kilos de riz'), 2.5);
    });

    test('aucun nombre, aucune quantite', () {
      expect(quantityOf('combien de riz'), isNull);
      expect(quantityOf('vendu du sucre'), isNull);
    });

    test('une repetition compte apres le nom', () {
      // [vendu][du sucre][deux][fois]
      expect(quantityOf('vendu du sucre deux fois'), 2);
    });
  });

  group('ou s arrete la recherche arriere', () {
    test('un nombre adjacent est lu tel qu il est dit', () {
      // "un deux sucre" dit un et deux, pas un seul sucre.
      final List<String> tokens = harness.tokensOf('vendu un deux sucre');

      expect(lines.read(tokens, firstName(tokens)).quantity, 3);
    });

    test('la lecture la plus longue qui finit au nom est retenue', () {
      // Une suite de nombres n en fait qu un: le compte vaut treize, pas quatre.
      final List<String> tokens = harness.tokensOf(
        'vendu trois un deux trois quatre sucre',
      );

      expect(lines.read(tokens, firstName(tokens)).quantity, 13);
    });

    test(
      'un nombre coupe par un mot qui n est pas un pont n est pas emprunte',
      () {
        // Ni "et" ni "du" ne vont ensemble dans un seul compte: rien ne finit au
        // bon endroit, donc aucune quantite plutot qu une quantite inventee.
        final List<String> tokens = harness.tokensOf('vendu trois et du sucre');

        expect(lines.read(tokens, firstName(tokens)).quantity, isNull);
      },
    );
  });

  group('montant', () {
    test('apres "a"', () {
      expect(amountOf('vendu un sucre a cent francs'), 100);
      expect(amountOf('reçu du riz a cinq cent soixante'), 560);
      expect(amountOf('reçu du ciment a quatre mille huit cents'), 4800);
    });

    test('direct avec mot de devise (sans "a")', () {
      expect(amountOf('vendu riz deux mille francs'), 2000);
      expect(amountOf('vendu savon 500 cfa'), 500);
      expect(amountOf('vendu huile mille cinq cents fcfa'), 1500);
    });

    test('un montant suivi de devise n est pas confondu avec une quantite', () {
      // "riz deux mille francs" -> montant 2000, pas quantite 2000.
      expect(amountOf('vendu riz deux mille francs'), 2000);
      expect(quantityOf('vendu riz deux mille francs'), isNull);

      // "deux savon 500 cfa" -> quantite 2, montant 500.
      expect(quantityOf('vendu deux savon 500 cfa'), 2);
      expect(amountOf('vendu deux savon 500 cfa'), 500);

      // "savon deux a 500 cfa" -> quantite 2, montant 500.
      expect(quantityOf('vendu savon deux a 500 cfa'), 2);
      expect(amountOf('vendu savon deux a 500 cfa'), 500);

      // "savon deux morceaux 500 cfa" -> quantite 2, montant 500.
      expect(quantityOf('vendu savon deux morceaux 500 cfa'), 2);
      expect(amountOf('vendu savon deux morceaux 500 cfa'), 500);
    });

    test('un montant ne se deplace pas sur la ligne suivante', () {
      // Le prix annonce est celui du riz, pas du sucre qui suit.
      expect(amountOf('vendu un riz a sept cents le kilo et un sucre'), 700);
    });

    test('aucun montant', () {
      expect(amountOf('vendu un sucre'), isNull);
    });
  });

  group('unite mal entendue', () {
    test('la meme tolerance que pour un nom de produit', () {
      expect(quantityOf('vendu 2 saché de sucre'), 2);
      expect(quantityOf('vendu 2 sachett de sucre'), 2);
    });

    test('une quantite n est jamais lue comme une unite', () {
      // "deux" ne ressemble a aucune unite, et "sept" non plus.
      expect(quantityOf('vendu sept savon'), 7);
    });
  });
}
