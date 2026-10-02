import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_state.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';

Product _product({
  required String id,
  required String name,
  int quantity = 10,
  int alertThreshold = 3,
  int purchasePrice = 1000,
  String category = 'Alimentaire',
}) => Product(
  id: id,
  name: name,
  category: category,
  unit: 'Pièces',
  purchasePrice: purchasePrice,
  salePrice: purchasePrice + 500,
  quantity: quantity,
  alertThreshold: alertThreshold,
);

/// Attend la première émission d'un provider dérivé de [productsProvider]
/// puis retourne sa valeur déballée.
Future<T> _read<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  container.read(provider).whenData((_) {});
  await Future<void>.delayed(Duration.zero);
  return container.read(provider).requireValue;
}

void main() {
  test('stock overview aggregates counts and value (UC9)', () async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value([
            _product(id: '1', name: 'ok', quantity: 10, purchasePrice: 1000),
            _product(
              id: '2',
              name: 'critical',
              quantity: 2,
              purchasePrice: 2000,
            ),
            _product(id: '3', name: 'rupture', quantity: 3, purchasePrice: 500),
            _product(id: '4', name: 'out', quantity: 0, purchasePrice: 1000),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final overview = await _read(container, stockOverviewProvider);

    expect(overview.totalProducts, 4);
    expect(overview.totalUnits, 15);
    expect(overview.outOfStock, 1);
    expect(overview.rupture, 1);
    expect(overview.critical, 1);
    // 10x1000 + 2x2000 + 3x500 + 0x1000
    expect(overview.stockValue, 15500);
    expect(overview.needsAttention, 3);
    expect(overview.hasAlerts, isTrue);
  });

  test('stock overview is empty with no product', () async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);

    final overview = await _read(container, stockOverviewProvider);

    expect(overview.totalProducts, 0);
    expect(overview.stockValue, 0);
    expect(overview.hasAlerts, isFalse);
  });

  test('stock states expose the level per product', () async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value([
            _product(id: '1', name: 'ok'),
            _product(id: '2', name: 'out', quantity: 0),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final states = await _read(container, stockStatesProvider);

    expect(states, hasLength(2));
    expect(states.first.level, StockAlertLevel.ok);
    expect(states.first.missingUnits, 0);
    expect(states.last.level, StockAlertLevel.outOfStock);
    expect(states.last.missingUnits, 3);
  });

  test('missing units only counts when an alert is raised', () async {
    final state = StockState(
      productId: '1',
      productName: 'sucre',
      quantity: 1,
      alertThreshold: 5,
      level: StockAlertLevel.critical,
      lastMovementAt: null,
    );

    expect(state.isCritical, isTrue);
    expect(state.missingUnits, 4);
  });

  test('the alert filter keeps only the matching products', () async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value([
            _product(id: '1', name: 'ok'),
            _product(id: '2', name: 'out', quantity: 0),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _read(container, stockStatesProvider);
    container
        .read(stockAlertFilterProvider.notifier)
        .select(StockAlertLevel.outOfStock);

    final filtered = await _read(container, alertedProductsProvider);

    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'out');
  });

  test('clearing the alert filter restores the full list', () async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value([
            _product(id: '1', name: 'ok'),
            _product(id: '2', name: 'out', quantity: 0),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _read(container, stockStatesProvider);
    container
        .read(stockAlertFilterProvider.notifier)
        .select(StockAlertLevel.outOfStock);
    await _read(container, alertedProductsProvider);

    container.read(stockAlertFilterProvider.notifier).select(null);
    final all = await _read(container, alertedProductsProvider);

    expect(all, hasLength(2));
  });
}
