import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/intent_detector.dart';

import 'rule_parser_harness.dart';

void main() {
  final RuleParserHarness harness = RuleParserHarness();
  final IntentDetector detector = harness.detector;

  /// The intent found in [raw], or the empty string when none is.
  String detect(String raw) {
    final IntentDetection? found = detector.detect(
      harness.normalizer.normalize(raw),
    );
    return found?.intentId ?? '';
  }

  /// Index just past the matched trigger, or -1.
  int triggerEnd(String raw) {
    final IntentDetection? found = detector.detect(
      harness.normalizer.normalize(raw),
    );
    return found?.triggerEnd ?? -1;
  }

  group('ce que le catalogue atteint', () {
    test('chaque commande est atteignable par un de ses declencheurs', () {
      const Map<String, List<String>> samples = <String, List<String>>{
        'record_sale': <String>['vendu deux savon', 'ça part une bière'],
        'record_restock': <String>[
          'reçu trois sacs de ciment',
          "j'ai acheté du riz",
        ],
        'query_stock': <String>[
          'combien de riz',
          'stock du sucre',
          'il reste combien de lait',
        ],
        'cancel_last_sale': <String>[
          'annule la dernière vente',
          'je me trompe',
        ],
      };

      for (final MapEntry<String, List<String>> entry in samples.entries) {
        for (final String raw in entry.value) {
          expect(detect(raw), entry.key, reason: raw);
        }
      }
    });
  });

  group('le declencheur le plus long gagne', () {
    test('"il reste combien" bat "combien"', () {
      expect(detect('il reste combien de maggi'), 'query_stock');
    });

    test('"combien il reste" bat "combien"', () {
      expect(detect('combien il reste de riz'), 'query_stock');
    });

    test('"stock de" et "combien de" ne declenchent pas autre chose', () {
      expect(detect('stock de savon'), 'query_stock');
      expect(detect('combien de pates'), 'query_stock');
    });

    test('une annulation garde la priorite sur une vente', () {
      expect(detect("annule la vente d'hier"), 'cancel_last_sale');
    });
  });

  group('aucun declencheur', () {
    test('une phrase hors commerce ne rend aucun intent', () {
      expect(detect('quel temps fait-il'), '');
      expect(detect('raconte une histoire'), '');
      expect(detect(''), '');
    });

    test('un mot qui contient un declencheur ne le declenche pas', () {
      // "vente" seul ne vaut pas "vente de".
      expect(detect('la vente est bonne'), '');
    });
  });

  group('position du declencheur', () {
    test('vise juste apres le declencheur', () {
      // [vendu][deux savon]
      expect(triggerEnd('vendu deux savon'), 1);
    });

    test('compte la longueur du declencheur et pas celle du mot', () {
      // [il reste combien][de maggi]
      expect(triggerEnd('il reste combien de maggi'), 3);
    });

    test('reste absent quand rien n est trouve', () {
      expect(triggerEnd('bonjour'), -1);
    });
  });

  group('normalisation partagee', () {
    test(
      'l apostrophe elidee du declencheur et celle de la phrase coincident',
      () {
        expect(detect("j'ai vendu deux savon"), 'record_sale');
      },
    );

    test('les accents du declencheur et de la phrase coincident', () {
      expect(detect('annule la dernière vente'), 'cancel_last_sale');
    });
  });
}
