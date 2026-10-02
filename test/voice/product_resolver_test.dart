import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/product_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';

import 'rule_parser_harness.dart';

void main() {
  final RuleParserHarness harness = RuleParserHarness();
  final ProductResolver resolver = harness.resolver;

  /// What the resolver concludes about the first product name of [raw].
  ProductResolution resolve(String raw) {
    final List<String> tokens = harness.tokensOf(raw);
    final ProductSpan? span = resolver.matchAt(tokens, 0);
    return span?.resolution ??
        const ProductResolution(status: ResolutionStatus.unknown);
  }

  /// The single product the words name, or the empty string.
  String productId(String raw) => resolve(raw).product?.id ?? '';

  group('nom et alias', () {
    test('le nom du catalogue', () {
      expect(productId('sucre'), 'p_sucre');
    });

    test('un alias', () {
      expect(productId('maggi'), 'p_maggi');
    });

    test('un alias compose', () {
      expect(productId('savon de menage'), 'p_savon');
    });

    test('le plus long nom gagne, jamais un prefixe', () {
      // "savon" repond aussi, mais "savon de menage" est le nom de la fiche.
      expect(productId('savon de menage'), 'p_savon');
      expect(productId('huile de palme'), 'p_huile_palme');
    });

    test('un produit archive se reconnait', () {
      // Un produit archive n'a pas de "produit" utilisable: il est signale, jamais
      // rendu. C'est ce qui distingue un refus d'une resolution.
      final ProductResolution resolution = resolve('lait en boite');

      expect(resolution.status, ResolutionStatus.archived);
      expect(resolution.candidates.single.product.id, 'p_vieux_lait');
    });
  });

  group('pluriel de la part du commerçant', () {
    test('sur le premier mot du nom', () {
      expect(productId('laits en poudre'), 'p_lait_poudre');
    });

    test('sur le dernier mot du nom', () {
      expect(productId('riz parfumes'), 'p_riz');
    });

    test('sur un nom simple', () {
      expect(productId('sucres'), 'p_sucre');
    });
  });

  group('nom non designant', () {
    test('"huile" seul designe deux produits', () {
      final ProductResolution resolution = resolve('huile');

      expect(resolution.status, ResolutionStatus.ambiguous);
      expect(
        resolution.products.map((ProductSnapshot p) => p.id),
        containsAll(<String>['p_huile', 'p_huile_palme']),
      );
    });

    test('le pluriel de "huile" aussi', () {
      expect(resolve('huiles').status, ResolutionStatus.ambiguous);
    });
  });

  group('produit archive', () {
    test('seul, il est refuse', () {
      expect(resolve('lait metal').status, ResolutionStatus.archived);
    });

    test('il ne dispute pas le nom a un produit actif', () {
      // "lait concentre" est un alias du produit archive et du produit vendu.
      // Sans filtre, les deux feraient egalite et la vente serait refusee a tort.
      expect(productId('lait concentre'), 'p_lait');
    });
  });

  group('faute de reconnaissance', () {
    test('une faute proche est acceptee', () {
      expect(productId('magis'), 'p_maggi');
    });

    test('deux fautes sur huit lettres restent un mot inconnu', () {
      // Le jeu fige attend "conssrv" pour "conserve". L'accepter demanderait
      // d'abaisser fuzzyThreshold, ce qui n'est pas decide ici.
      expect(resolve('conssrv').status, ResolutionStatus.unknown);
    });

    test('un mot sans rapport ne devient pas un produit', () {
      expect(resolve('truc').status, ResolutionStatus.unknown);
      expect(resolve('meteo').status, ResolutionStatus.unknown);
    });
  });

  group('bornes', () {
    test('rien a partir de la fin de la liste', () {
      expect(resolver.matchAt(<String>['sucre'], 1), isNull);
    });

    test('une liste vide', () {
      expect(resolver.matchAt(<String>[], 0), isNull);
    });

    test('la longueur du nom est celle du nom', () {
      final ProductSpan? span = resolver.matchAt(harness.tokensOf('sucre'), 0);

      expect(span?.start, 0);
      expect(span?.length, 1);
    });
  });
}
