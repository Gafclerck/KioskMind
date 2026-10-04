import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/stock_movement_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/record_stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/presentation/pages/record_stock_movement_page.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_providers.dart';

const _riz = Product(
  id: '1',
  name: 'Sac de Riz',
  category: 'Alimentaire',
  unit: 'Sacs',
  purchasePrice: 4200,
  salePrice: 5000,
  quantity: 10,
  alertThreshold: 3,
);

class _FakeStockMovementRepository implements StockMovementRepository {
  final List<StockMovement> recorded = [];
  Object? failure;

  @override
  Future<void> recordMovement(StockMovement movement) async {
    if (failure != null) throw failure!;
    recorded.add(movement);
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) =>
      Stream.value(const []);
}

Widget _page(
  _FakeStockMovementRepository repository, {
  Product product = _riz,
  StockMovementDirection direction = StockMovementDirection.inbound,
}) => ProviderScope(
  overrides: [stockMovementRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    home: RecordStockMovementPage(
      product: product,
      initialDirection: direction,
    ),
  ),
);

Finder _quantity() => find.byKey(const ValueKey<String>('movement_quantity'));

Finder _submit() => find.byKey(const ValueKey<String>('movement_submit'));

void main() {
  testWidgets('defaults to an inbound movement', (tester) async {
    await tester.pumpWidget(_page(_FakeStockMovementRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Entrée de stock'), findsOneWidget);
    expect(find.text('Stock actuel : 10 sacs'), findsOneWidget);
    expect(find.text('Achat / Réapprovisionnement'), findsOneWidget);
    expect(_submit(), findsOneWidget);
  });

  testWidgets('validates the quantity before submitting', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(find.text('Saisissez un nombre'), findsOneWidget);
    expect(repository.recorded, isEmpty);
  });

  testWidgets('rejects a zero quantity', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '0');
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(
      find.text('La quantité doit être supérieure à zéro'),
      findsOneWidget,
    );
    expect(repository.recorded, isEmpty);
  });

  testWidgets('records an inbound movement (UC7)', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '12');
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(find.text('Entrée enregistrée !'), findsOneWidget);
    expect(repository.recorded, hasLength(1));
    expect(repository.recorded.single.type, StockMovementType.purchase);
    expect(repository.recorded.single.quantity, 12);
    expect(repository.recorded.single.productId, '1');
  });

  testWidgets('keeps the note when provided', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '5');
    await tester.enterText(
      find.byKey(const ValueKey<String>('movement_note')),
      'Livraison M. Diallo',
    );
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(repository.recorded.single.note, 'Livraison M. Diallo');
  });

  testWidgets('switches to an outbound movement (UC8)', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sortie'));
    await tester.pumpAndSettle();

    expect(find.text('Sortie de stock'), findsOneWidget);
    expect(find.text('Perte, casse ou don'), findsOneWidget);
    expect(find.text('Motif'), findsOneWidget);
  });

  testWidgets('blocks an outbound movement above the available stock', (
    tester,
  ) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sortie'));
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '25');
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(find.text('Stock insuffisant (10)'), findsOneWidget);
    expect(repository.recorded, isEmpty);
  });

  testWidgets('records a manual out movement with its reason', (tester) async {
    final repository = _FakeStockMovementRepository();
    await tester.pumpWidget(
      _page(repository, direction: StockMovementDirection.outbound),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '2');
    await tester.tap(find.text('Perte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casse'));
    await tester.pumpAndSettle();

    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(find.text('Sortie enregistrée !'), findsOneWidget);
    expect(repository.recorded.single.reason, StockMovementReason.breakage);
    expect(repository.recorded.single.type, StockMovementType.manualOut);
    expect(repository.recorded.single.signedQuantity, -2);
  });

  testWidgets('reports a repository failure and allows a retry', (
    tester,
  ) async {
    final repository = _FakeStockMovementRepository()
      ..failure = StateError('offline');
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(_quantity(), '7');
    await tester.tap(_submit());
    await tester.pumpAndSettle();

    expect(find.text('Erreur de connexion'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(repository.recorded, hasLength(1));
    expect(repository.recorded.single.quantity, 7);
  });

  testWidgets(
    'shows an insufficient stock message when the server rejects it',
    (tester) async {
      final repository = _FakeStockMovementRepository()
        ..failure = const StockMovementFailure.insufficientStock(
          requested: 4,
          available: 1,
        );
      await tester.pumpWidget(
        _page(repository, direction: StockMovementDirection.outbound),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_quantity(), '3');
      await tester.tap(_submit());
      await tester.pumpAndSettle();

      expect(find.text('Stock insuffisant'), findsOneWidget);
      expect(find.textContaining('1 unité'), findsOneWidget);
    },
  );
}
