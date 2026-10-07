import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/errors/failure.dart';
import 'package:kiosk_mind/core/usecase/result.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/stock_movement.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/stock_movement_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/record_stock_movement.dart';
import 'package:kiosk_mind/features/voice_assistant/data/catalog/in_memory_product_catalog.dart';
import 'package:kiosk_mind/features/voice_assistant/data/handlers/real/real_record_restock_handler.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_input.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/intent_result.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/entities/product_snapshot.dart';
import 'package:kiosk_mind/features/voice_assistant/domain/ports/command_context.dart';

final class _FakeStockMovementRepository implements StockMovementRepository {
  final List<StockMovement> movements = <StockMovement>[];

  @override
  Future<void> recordMovement(StockMovement movement) async {
    movements.add(movement);
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) =>
      Stream<List<StockMovement>>.value(
        movements.where((m) => m.productId == productId).toList(),
      );
}

final class _FakeThrowingStockMovementRepository
    implements StockMovementRepository {
  @override
  Future<void> recordMovement(StockMovement movement) async {
    throw Exception('Firestore write failure');
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) =>
      Stream<List<StockMovement>>.empty();
}

ProductSnapshot _product(
  String id, {
  required String name,
  required double stock,
  double price = 500,
  double? purchasePrice = 400,
  String unit = 'PIECE',
  bool isArchived = false,
}) {
  return ProductSnapshot(
    id: id,
    name: name,
    aliases: const <String>[],
    unit: unit,
    price: price,
    purchasePrice: purchasePrice,
    stock: stock,
    alertThreshold: 0,
    averageDailyQty: 0,
    isArchived: isArchived,
  );
}

void main() {
  late _FakeStockMovementRepository repo;
  late InMemoryProductCatalog catalog;
  late RealRecordRestockHandler handler;

  final CommandContext context = (
    commandId: 'cmd-restock-1',
    dateTime: DateTime(2026, 3, 1, 10),
    source: CommandSource.voice,
  );

  setUp(() {
    repo = _FakeStockMovementRepository();
    catalog = InMemoryProductCatalog(<ProductSnapshot>[
      _product('p_sucre', name: 'Sucre roux', stock: 10),
      _product('p_riz', name: 'Riz 5kg', stock: 5),
      _product(
        'p_archived',
        name: 'Produit archive',
        stock: 2,
        isArchived: true,
      ),
    ]);
    handler = RealRecordRestockHandler(
      recordStockIn: RecordStockIn(repo),
      catalogReader: catalog,
    );
  });

  group('RealRecordRestockHandler', () {
    test('has intentId record_restock', () {
      expect(handler.intentId, equals('record_restock'));
    });

    test('records restock and delegates to RecordStockIn', () async {
      final input = const RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'p_sucre',
            productName: 'Sucre roux',
            qty: 5,
            spokenUnitCost: 400,
          ),
        ],
      );

      final result = await handler.execute(context, input);

      expect(result, isA<Success<RecordRestockResult>>());
      final success = result as Success<RecordRestockResult>;
      expect(success.value.movementIds, equals(['cmd-restock-1-0']));
      expect(success.value.lines.length, equals(1));
      expect(success.value.lines.first.productId, equals('p_sucre'));
      expect(success.value.lines.first.name, equals('Sucre roux'));
      expect(success.value.lines.first.qty, equals(5));
      expect(success.value.lines.first.resultingStock, equals(15));
      expect(success.value.lines.first.appliedUnitCost, equals(400));

      expect(repo.movements.length, equals(1));
      final movement = repo.movements.first;
      expect(movement.id, equals('cmd-restock-1-0'));
      expect(movement.productId, equals('p_sucre'));
      expect(movement.quantity, equals(5));
      expect(movement.type, equals(StockMovementType.purchase));
      expect(movement.reason, equals(StockMovementReason.purchase));
    });

    test('records multiple restock lines in order', () async {
      final input = const RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'p_sucre',
            productName: 'Sucre roux',
            qty: 3,
          ),
          RestockIntentLine(
            productId: 'p_riz',
            productName: 'Riz 5kg',
            qty: 10,
          ),
        ],
      );

      final result = await handler.execute(context, input);

      expect(result, isA<Success<RecordRestockResult>>());
      final success = result as Success<RecordRestockResult>;
      expect(
        success.value.movementIds,
        equals(['cmd-restock-1-0', 'cmd-restock-1-1']),
      );
      expect(success.value.lines.length, equals(2));
      expect(success.value.lines[0].resultingStock, equals(13));
      expect(success.value.lines[1].resultingStock, equals(15));

      expect(repo.movements.length, equals(2));
      expect(repo.movements[0].productId, equals('p_sucre'));
      expect(repo.movements[1].productId, equals('p_riz'));
    });

    test(
      'replayed command returns cached result without duplicate writes',
      () async {
        final input = const RestockIntentInput(
          items: [
            RestockIntentLine(
              productId: 'p_sucre',
              productName: 'Sucre roux',
              qty: 2,
            ),
          ],
        );

        final first = await handler.execute(context, input);
        final second = await handler.execute(context, input);

        expect(first, isA<Success<RecordRestockResult>>());
        expect(second, isA<Success<RecordRestockResult>>());
        expect(repo.movements.length, equals(1));
      },
    );

    test('refuses empty items', () async {
      const input = RestockIntentInput(items: []);
      final result = await handler.execute(context, input);

      expect(result, isA<Failed<RecordRestockResult>>());
      expect(
        (result as Failed<RecordRestockResult>).failure,
        isA<EmptyItems>(),
      );
    });

    test('refuses unknown product', () async {
      const input = RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'non_existent',
            productName: 'Inconnu',
            qty: 2,
          ),
        ],
      );
      final result = await handler.execute(context, input);

      expect(result, isA<Failed<RecordRestockResult>>());
      expect(
        (result as Failed<RecordRestockResult>).failure,
        isA<UnknownProduct>(),
      );
    });

    test('refuses archived product', () async {
      const input = RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'p_archived',
            productName: 'Archive',
            qty: 1,
          ),
        ],
      );
      final result = await handler.execute(context, input);

      expect(result, isA<Failed<RecordRestockResult>>());
      expect(
        (result as Failed<RecordRestockResult>).failure,
        isA<ArchivedProduct>(),
      );
    });

    test('refuses invalid quantity <= 0', () async {
      const input = RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'p_sucre',
            productName: 'Sucre roux',
            qty: 0,
          ),
        ],
      );
      final result = await handler.execute(context, input);

      expect(result, isA<Failed<RecordRestockResult>>());
      expect(
        (result as Failed<RecordRestockResult>).failure,
        isA<InvalidQuantity>(),
      );
    });

    test('returns Failed when RecordStockIn throws Exception', () async {
      final failingRepo = _FakeThrowingStockMovementRepository();
      final failingHandler = RealRecordRestockHandler(
        recordStockIn: RecordStockIn(failingRepo),
        catalogReader: catalog,
      );

      const input = RestockIntentInput(
        items: [
          RestockIntentLine(
            productId: 'p_sucre',
            productName: 'Sucre roux',
            qty: 2,
          ),
        ],
      );

      final result = await failingHandler.execute(context, input);

      expect(result, isA<Failed<RecordRestockResult>>());
    });
  });
}
