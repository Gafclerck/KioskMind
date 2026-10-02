import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/text_normalizer.dart';

void main() {
  const TextNormalizer normalizer = TextNormalizer();

  String text(String raw) => normalizer.normalize(raw).text;

  group('la forme normalisee', () {
    test('les tokens sont la source, le texte en est une vue', () {
      final NormalizedText normalized = normalizer.normalize('Vendu un café');

      expect(normalized.tokens, <String>['vendu', 'un', 'cafe']);
      expect(normalized.text, 'vendu un cafe');
      expect(normalized.toString(), normalized.text);
      expect(normalized.length, 3);
      expect(normalized.isEmpty, isFalse);
    });

    test('un span relit une portion de la phrase', () {
      final NormalizedText normalized = normalizer.normalize('vendu du sucre');

      expect(normalized.span(2, 1), 'sucre');
      expect(normalized.span(1, 2), 'du sucre');
      expect(normalized.span(0, 9), 'vendu du sucre');
    });

    test('une phrase vide reste vide', () {
      final NormalizedText normalized = normalizer.normalize('bonjour');

      expect(normalized.isEmpty, isTrue);
      expect(normalized.length, 0);
      expect(normalized.span(0, 1), '');
    });
  });

  group('mise en forme', () {
    test('minuscules', () {
      expect(text('VENDU 2 SAVON'), 'vendu 2 savon');
    });

    test('accents retires', () {
      expect(text('vendu un café'), 'vendu un cafe');
      expect(text('vendu un thÉ'), 'vendu un the');
      expect(text('vendu\tun\tpâtes'), 'vendu un pates');
    });

    test('espaces multiples et bords reduits', () {
      expect(text('  vendu   deux   savon  '), 'vendu deux savon');
    });

    test(' ponctuation non decimale retiree', () {
      expect(text('vendu 2 savon.'), 'vendu 2 savon');
      expect(text('vendu 2 savon?'), 'vendu 2 savon');
      expect(text('vendu 2 allumettes!'), 'vendu 2 allumettes');
      expect(text('stock: du sucre'), 'stock du sucre');
      expect(text('bonjour, vendu un savon'), 'vendu un savon');
    });

    test('virgule decimale conservee entre deux chiffres', () {
      expect(text('vendu 4,5 kilos de riz'), 'vendu 4.5 kilos de riz');
      expect(text('eau minerale 1,5 l'), 'eau minerale 1.5 l');
    });

    test('point decimal conserve', () {
      expect(text('vendu 2.5 kilos de riz'), 'vendu 2.5 kilos de riz');
    });

    test('chiffre colle a un mot separe', () {
      expect(text('vendu 2PACK de pate'), 'vendu 2 pack de pate');
      expect(text('vendu 3cafe'), 'vendu 3 cafe');
      expect(text('vendu 5.allumettes'), 'vendu 5 allumettes');
    });

    test('tiret devient un separateur', () {
      expect(
        text('vendu quatre-vingt-dix-sept biere'),
        'vendu quatre vingt dix sept biere',
      );
      expect(text('annule celle-la'), 'annule celle la');
    });
  });

  group('elisions', () {
    test('article elide devant voyelle', () {
      expect(text("vendu de l'eau"), 'vendu eau');
      expect(text("vendu d'huile"), 'vendu huile');
      expect(
        text("vendu un litre d'huile de palme"),
        'vendu un litre huile de palme',
      );
    });

    test('de devant elision disparait entierement', () {
      expect(text("niveau de stock de l'eau"), 'niveau de stock eau');
      expect(text("combien de bidons d'huile"), 'combien de bidons huile');
    });

    test('pronominal conserve sa consonne', () {
      expect(text("j'ai vendu deux sucre"), 'jai vendu deux sucre');
      expect(text("je me trompe, jannule"), 'je me trompe jannule');
    });

    test('negation et auxiliaire', () {
      expect(text("c'est faux"), 'cest faux');
      expect(text("ce qui manque"), 'ce qui manque');
      expect(text("n'est pas du riz"), 'nest pas du riz');
    });
  });

  group('jetons de remplissage', () {
    test('removes fillers', () {
      expect(normalizer.normalize('euh vendu deux sucre euh').tokens, <String>[
        'vendu',
        'deux',
        'sucre',
      ]);
    });

    test('keeps anaphora markers', () {
      expect(
        text("vendu le meme sucre que tout a l'heure"),
        'vendu le meme sucre que tout a lheure',
      );
      expect(text('stock comme hier'), 'stock comme hier');
    });
  });

  test('la virgule entre deux chiffres ne coupe pas le jeton', () {
    expect(normalizer.normalize('vendu 4,5 kilos').tokens, contains('4.5'));
  });

  test('une chaine vide reste vide', () {
    expect(normalizer.normalize('').tokens, isEmpty);
    expect(normalizer.normalize('   ').tokens, isEmpty);
  });
}
