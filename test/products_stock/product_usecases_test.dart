import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/repositories/product_repository.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/delete_product.dart';
import 'package:kiosk_mind/features/products_stock/domain/usecases/update_product.dart';

class _FakeProductRepository implements ProductRepository {
  final List<Product> created = [];
  final List<Product> updated = [];
  final List<String> deleted = [];

  @override
  Future<void> createProduct(Product product) async => created.add(product);

  @override
  Future<void> updateProduct(Product product) async => updated.add(product);

  @override
  Future<void> deleteProduct(String productId) async => deleted.add(productId);

  @override
  Stream<List<Product>> watchProducts() => Stream.value(const []);
}

const _product = Product(
  id: 'abc',
  name: 'Sac de Riz',
  category: 'Alimentaire',
  unit: 'Sacs',
  purchasePrice: 4200,
  salePrice: 5000,
  quantity: 10,
  alertThreshold: 3,
);

const _productWithoutId = Product(
  id: '',
  name: 'Sac de Riz',
  category: 'Alimentaire',
  unit: 'Sacs',
  purchasePrice: 4200,
  salePrice: 5000,
  quantity: 10,
  alertThreshold: 3,
);

void main() {
  group('UpdateProduct', () {
    test('delegates the update to the repository', () async {
      final repository = _FakeProductRepository();

      await UpdateProduct(repository)(_product);

      expect(repository.updated, [_product]);
    });

    test('rejects a product without an id', () async {
      final repository = _FakeProductRepository();

      expect(
        () => UpdateProduct(repository)(_productWithoutId),
        throwsArgumentError,
      );
      expect(repository.updated, isEmpty);
    });
  });

  group('DeleteProduct', () {
    test('delegates the deletion to the repository', () async {
      final repository = _FakeProductRepository();

      await DeleteProduct(repository)('abc');

      expect(repository.deleted, ['abc']);
    });

    test('rejects an empty product id', () async {
      final repository = _FakeProductRepository();

      expect(() => DeleteProduct(repository)(''), throwsArgumentError);
      expect(repository.deleted, isEmpty);
    });
  });
}
