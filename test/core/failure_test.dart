import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';

void main() {
  group('Failure', () {
    test('carries an uppercase underscore code, never displayable text', () {
      const List<Failure> failures = <Failure>[
        UnknownProduct(productId: 'p1'),
        ArchivedProduct(productId: 'p1'),
        InvalidQuantity(productId: 'p1', qty: 0),
        EmptyItems('record_sale'),
        SaleNotFound('s1'),
        AlreadyCancelled('s1'),
      ];

      for (final Failure failure in failures) {
        expect(failure.code, matches(RegExp(r'^[A-Z][A-Z_]*$')));
      }
      expect(
        failures.map((Failure f) => f.code).toSet(),
        hasLength(failures.length),
        reason: 'chaque echec a son propre code',
      );
    });

    test('keeps the identifier the caller had at hand', () {
      expect(const UnknownProduct(productId: 'p1').productId, 'p1');
      expect(const ArchivedProduct(productId: 'p2').productId, 'p2');
      expect(const InvalidQuantity(productId: 'p3', qty: -2).qty, -2);
      expect(const EmptyItems('record_restock').intentId, 'record_restock');
      expect(const SaleNotFound('s9').saleId, 's9');
      expect(const AlreadyCancelled('s8').saleId, 's8');
    });

    test('leaves an optional product name unset rather than empty', () {
      expect(const UnknownProduct(productId: 'p1').productName, isNull);
      expect(
        const ArchivedProduct(productId: 'p1', productName: 'Lait').productName,
        'Lait',
      );
    });
  });
}
