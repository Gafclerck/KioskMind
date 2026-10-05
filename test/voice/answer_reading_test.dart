import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/voice_assistant/data/extractors/product_name_resolver.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/doubt.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/answer_reading.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/services/french_number_parser.dart';

import 'rule_parser_harness.dart';

/// One line of the table: what was said, what it was asked about, what it gives.
typedef _Row = ({String said, DoubtKind asked, Object? gives});

/// Reading the words the merchant speaks to answer a question.
///
/// A null is a legitimate outcome and is checked as such: an answer that carries
/// nothing must leave the doubt standing rather than complete a line by guess.
void main() {
  final RuleParserHarness harness = RuleParserHarness();
  final AnswerReading reading = AnswerReading(
    normalizer: harness.normalizer,
    numbers: const FrenchNumberParser(),
    products: ProductNameResolver(
      resolver: harness.resolver,
      normalizer: harness.normalizer,
    ),
  );

  Object? read(String said, DoubtKind asked) =>
      reading.read(said, asked: asked);

  void table(
    String title,
    List<_Row> rows,
    Object? Function(Object? value) project,
  ) {
    group(title, () {
      for (final _Row row in rows) {
        test('"${row.said}" pour ${row.asked.name}', () {
          expect(project(read(row.said, row.asked)), row.gives);
        });
      }
    });
  }

  table('une reponse de produit', <_Row>[
    (said: 'sucre', asked: DoubtKind.missingProduct, gives: 'p_sucre'),
    (said: 'le sucre', asked: DoubtKind.missingProduct, gives: 'p_sucre'),
    (said: 'du sucre', asked: DoubtKind.missingProduct, gives: 'p_sucre'),
    (said: 'Sucre', asked: DoubtKind.missingProduct, gives: 'p_sucre'),
    (said: 'euh le sucre', asked: DoubtKind.missingProduct, gives: 'p_sucre'),
    (said: 'lait', asked: DoubtKind.missingProduct, gives: 'p_lait'),
    (said: 'maggi', asked: DoubtKind.unknownProduct, gives: 'p_maggi'),
    (
      said: 'huile de palme',
      asked: DoubtKind.ambiguousProduct,
      gives: 'p_huile_palme',
    ),
    // An archived product is out of the spoken vocabulary: naming it is not an
    // answer, so the doubt stands instead of a line the catalog forbids.
    (said: 'vieux lait', asked: DoubtKind.missingProduct, gives: null),
    // A name no product answers for settles nothing, which is what asks again.
    (said: 'le aeroplane', asked: DoubtKind.missingProduct, gives: null),
    (said: '', asked: DoubtKind.missingProduct, gives: null),
    (said: 'le', asked: DoubtKind.missingProduct, gives: null),
    (said: 'deux', asked: DoubtKind.missingProduct, gives: null),
    // The article is only dropped at the start: "pas de sucre" refuses rather
    // than resolves.
    (said: 'pas de sucre', asked: DoubtKind.missingProduct, gives: null),
  ], _productIdOf);

  table('une reponse de quantite', <_Row>[
    (said: 'deux', asked: DoubtKind.missingQuantity, gives: 2.0),
    (said: 'trois', asked: DoubtKind.missingQuantity, gives: 3.0),
    (said: 'douze sachets', asked: DoubtKind.missingQuantity, gives: 12.0),
    (
      said: 'cinq cent soixante',
      asked: DoubtKind.missingQuantity,
      gives: 560.0,
    ),
    // The unit is not a number: the quantity is what was said, nothing more.
    (said: 'un paquet', asked: DoubtKind.missingQuantity, gives: 1.0),
    (said: 'le deux', asked: DoubtKind.missingQuantity, gives: 2.0),
    (
      said: 'cinq cent soixante',
      asked: DoubtKind.undeterminedQuantity,
      gives: 560.0,
    ),
    (said: 'beaucoup', asked: DoubtKind.missingQuantity, gives: null),
    (said: 'sucre', asked: DoubtKind.missingQuantity, gives: null),
    (said: '', asked: DoubtKind.missingQuantity, gives: null),
  ], (Object? value) => value);

  table('une reponse de confirmation', <_Row>[
    (said: 'oui', asked: DoubtKind.amountMismatch, gives: true),
    (said: 'Oui', asked: DoubtKind.amountMismatch, gives: true),
    (said: 'ouais', asked: DoubtKind.implausibleQuantity, gives: true),
    (said: 'ok', asked: DoubtKind.amountMismatch, gives: true),
    (said: 'exact', asked: DoubtKind.amountMismatch, gives: true),
    (said: 'euh oui', asked: DoubtKind.amountMismatch, gives: true),
    (said: "d'accord", asked: DoubtKind.amountMismatch, gives: true),
    (said: 'je confirme', asked: DoubtKind.implausibleQuantity, gives: true),
    (said: 'confirme', asked: DoubtKind.amountMismatch, gives: true),
    (said: 'valide', asked: DoubtKind.implausibleQuantity, gives: true),
    (said: "c'est bon", asked: DoubtKind.amountMismatch, gives: true),
    (said: 'vas-y', asked: DoubtKind.implausibleQuantity, gives: true),
    (said: 'yes', asked: DoubtKind.amountMismatch, gives: true),
    // Anything that is not a yes leaves the doubt standing: a merchant who says
    // "non" has not agreed to the sale.
    (said: 'non', asked: DoubtKind.amountMismatch, gives: false),
    (said: "non c'est pas bon", asked: DoubtKind.amountMismatch, gives: false),
    (said: 'annule', asked: DoubtKind.implausibleQuantity, gives: false),
    (said: 'je ne sais pas', asked: DoubtKind.amountMismatch, gives: false),
    (said: 'sucre', asked: DoubtKind.implausibleQuantity, gives: false),
    (said: '', asked: DoubtKind.amountMismatch, gives: null),
  ], (Object? value) => value);

  test('un doute qui n attend pas de valeur ne rend rien', () {
    for (final DoubtKind kind in DoubtKind.values) {
      if (kind.answersByProduct ||
          kind.answersByQuantity ||
          kind.answersByYesOrNo) {
        continue;
      }
      expect(read('sucre', kind), isNull, reason: kind.name);
    }
  });
}

/// The product an answer designated, as its id, for a table to compare.
Object? _productIdOf(Object? value) {
  if (value == null) {
    return null;
  }
  expect(value, isA<ProductSnapshot>());
  return (value as ProductSnapshot).id;
}
