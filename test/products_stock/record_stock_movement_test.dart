import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/stock_movement_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/record_stock_movement.dart';

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
      Stream.value(recorded);
}

final _now = DateTime.utc(2026, 1, 1);

StockMovement _in({
  String productId = 'p1',
  int quantity = 12,
  StockMovementReason reason = StockMovementReason.purchase,
}) => StockMovement(
  id: '',
  productId: productId,
  type: StockMovementType.purchase,
  reason: reason,
  quantity: quantity,
  createdAt: _now,
);

StockMovement _out({
  String productId = 'p1',
  int quantity = 3,
  StockMovementReason reason = StockMovementReason.loss,
}) => StockMovement(
  id: '',
  productId: productId,
  type: StockMovementType.manualOut,
  reason: reason,
  quantity: quantity,
  createdAt: _now,
);

void main() {
  group('RecordStockIn (UC7)', () {
    test('records a purchase movement', () async {
      final repository = _FakeStockMovementRepository();

      await RecordStockIn(repository)(_in());

      expect(repository.recorded, hasLength(1));
      expect(repository.recorded.single.type, StockMovementType.purchase);
      expect(repository.recorded.single.signedQuantity, 12);
    });

    test('rejects a movement without a product id', () async {
      final repository = _FakeStockMovementRepository();

      expect(
        () => RecordStockIn(repository)(_in(productId: '')),
        throwsArgumentError,
      );
      expect(repository.recorded, isEmpty);
    });

    test('rejects a zero or negative quantity', () async {
      final repository = _FakeStockMovementRepository();

      expect(
        () => RecordStockIn(repository)(_in(quantity: 0)),
        throwsA(isA<StockMovementFailure>()),
      );
      expect(
        () => RecordStockIn(repository)(_in(quantity: -5)),
        throwsA(isA<StockMovementFailure>()),
      );
    });

    test('refuses an outbound movement', () async {
      final repository = _FakeStockMovementRepository();
      final movement = StockMovement(
        id: '',
        productId: 'p1',
        type: StockMovementType.manualOut,
        reason: StockMovementReason.loss,
        quantity: 3,
        createdAt: _now,
      );

      expect(() => RecordStockIn(repository)(movement), throwsArgumentError);
    });

    test('propagates a repository failure', () async {
      final repository = _FakeStockMovementRepository()
        ..failure = StateError('offline');

      expect(() => RecordStockIn(repository)(_in()), throwsStateError);
    });
  });

  group('RecordStockOut (UC8)', () {
    test('records a manual out movement', () async {
      final repository = _FakeStockMovementRepository();

      await RecordStockOut(repository)(_out());

      expect(repository.recorded, hasLength(1));
      expect(repository.recorded.single.type, StockMovementType.manualOut);
      expect(repository.recorded.single.signedQuantity, -3);
    });

    for (final reason in [
      StockMovementReason.loss,
      StockMovementReason.breakage,
      StockMovementReason.donation,
    ]) {
      test('accepts the $reason reason', () async {
        final repository = _FakeStockMovementRepository();

        await RecordStockOut(repository)(_out(reason: reason));

        expect(repository.recorded.single.reason, reason);
      });
    }

    test('rejects a movement without a product id', () async {
      final repository = _FakeStockMovementRepository();

      expect(
        () => RecordStockOut(repository)(_out(productId: '')),
        throwsArgumentError,
      );
    });

    test('rejects a non positive quantity', () async {
      final repository = _FakeStockMovementRepository();

      expect(
        () => RecordStockOut(repository)(_out(quantity: 0)),
        throwsA(isA<StockMovementFailure>()),
      );
    });

    test('refuses an inbound movement', () async {
      final repository = _FakeStockMovementRepository();

      expect(() => RecordStockOut(repository)(_in()), throwsArgumentError);
    });
  });

  group('StockMovementFailure', () {
    test('describes an insufficient stock', () {
      const failure = StockMovementFailure.insufficientStock(
        requested: 10,
        available: 3,
      );

      expect(failure.reason, StockMovementFailureReason.insufficientStock);
      expect(failure.message, contains('3'));
    });
  });
}
