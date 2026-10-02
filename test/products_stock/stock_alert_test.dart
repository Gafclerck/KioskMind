import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/formatters.dart';

void main() {
  group('stockAlertLevelFor', () {
    test('is a rupture when the stock hits zero', () {
      expect(
        stockAlertLevelFor(quantity: 0, alertThreshold: 3),
        StockAlertLevel.outOfStock,
      );
    });

    test('is critical strictly below the threshold', () {
      expect(
        stockAlertLevelFor(quantity: 2, alertThreshold: 3),
        StockAlertLevel.critical,
      );
    });

    test('warns about a rupture exactly at the threshold', () {
      expect(
        stockAlertLevelFor(quantity: 3, alertThreshold: 3),
        StockAlertLevel.rupture,
      );
    });

    test('is ok strictly above the threshold', () {
      expect(
        stockAlertLevelFor(quantity: 4, alertThreshold: 3),
        StockAlertLevel.ok,
      );
    });

    test('only the non ok levels need attention', () {
      expect(StockAlertLevel.ok.needsAttention, isFalse);
      expect(StockAlertLevel.critical.needsAttention, isTrue);
      expect(StockAlertLevel.rupture.needsAttention, isTrue);
      expect(StockAlertLevel.outOfStock.needsAttention, isTrue);
    });
  });

  group('StockMovement', () {
    test('a purchase increases the stock', () {
      final movement = StockMovement(
        id: 'm1',
        productId: 'p1',
        type: StockMovementType.purchase,
        reason: StockMovementReason.purchase,
        quantity: 12,
        createdAt: _epoch,
      );

      expect(movement.signedQuantity, 12);
      expect(movement.impactLabel, '+12');
    });

    test('a manual out decreases the stock', () {
      final movement = StockMovement(
        id: 'm2',
        productId: 'p1',
        type: StockMovementType.manualOut,
        reason: StockMovementReason.breakage,
        quantity: 3,
        createdAt: _epoch,
      );

      expect(movement.signedQuantity, -3);
      expect(movement.impactLabel, '-3');
    });
  });

  group('formatCfa', () {
    test('groups thousands with commas', () {
      expect(formatCfa(2500), '2,500 FCFA');
      expect(formatCfa(4200), '4,200 FCFA');
      expect(formatCfa(320500), '320,500 FCFA');
    });

    test('leaves short amounts untouched', () {
      expect(formatCfa(450), '450 FCFA');
    });
  });

  group('formatUnit', () {
    test('pluralises above one', () {
      expect(formatUnit(12, 'Bouteilles'), 'bouteilles');
      expect(formatUnit(8, 'Sacs'), 'sacs');
    });

    test('singularises exactly one', () {
      expect(formatUnit(1, 'Bouteilles'), 'bouteille');
      expect(formatUnit(1, 'Sacs'), 'sac');
    });

    test('pluralises a unit stored in the singular', () {
      expect(formatUnit(3, 'Pièce'), 'pièces');
      expect(formatUnit(1, 'Pièce'), 'pièce');
    });
  });
}

final _epoch = DateTime.utc(2026, 1, 1);
