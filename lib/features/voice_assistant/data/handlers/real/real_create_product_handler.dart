import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../products_stock/domain/entities/product.dart';
import '../../../../products_stock/domain/usecases/create_product.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';

/// Real handler for creating a product via voice.
final class RealCreateProductHandler implements CreateProductHandler {
  RealCreateProductHandler({required this.createProduct});

  final CreateProduct createProduct;
  final Map<String, CreateProductResult> _recordedCommands =
      <String, CreateProductResult>{};

  @override
  String get intentId => 'create_product';

  @override
  Future<Result<CreateProductResult>> execute(
    CommandContext context,
    CreateProductInput input,
  ) async {
    final CreateProductResult? replayed = _recordedCommands[context.commandId];
    if (replayed != null) {
      return Success<CreateProductResult>(replayed);
    }

    if (input.name.trim().isEmpty) {
      return Failed<CreateProductResult>(const EmptyItems('create_product'));
    }

    final String productId = 'prod-${context.commandId}';
    final int salePrice = input.price.toInt();
    final int purchasePrice = (input.purchasePrice ?? input.price * 0.8)
        .toInt();
    final int quantity = (input.initialQty ?? 0).toInt();
    final String unit = input.unit ?? 'PIECE';
    final String category = input.category ?? 'Général';

    final Product product = Product(
      id: productId,
      name: input.name.trim(),
      category: category,
      unit: unit,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      quantity: quantity,
      alertThreshold: 5,
    );

    try {
      await createProduct(product);
      final CreateProductResult result = (
        productId: productId,
        name: input.name.trim(),
        price: input.price,
        purchasePrice: input.purchasePrice,
        initialQuantity: quantity.toDouble(),
        unit: unit,
      );
      _recordedCommands[context.commandId] = result;
      return Success<CreateProductResult>(result);
    } catch (_) {
      return Failed<CreateProductResult>(
        UnknownProduct(productId: productId, productName: input.name),
      );
    }
  }
}
