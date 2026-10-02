import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/product_form.dart';

Widget _form(void Function(Product) onSubmit, {Product? initialProduct}) =>
    MaterialApp(
      home: Scaffold(
        body: ProductForm(
          initialProduct: initialProduct,
          submitLabel: 'Enregistrer',
          isLoading: false,
          onSubmit: onSubmit,
        ),
      ),
    );

Finder _field(String key) => find.byKey(ValueKey<String>('product_form_$key'));

void main() {
  testWidgets('shows validation errors and does not submit when empty', (
    tester,
  ) async {
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p));

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Champ obligatoire'), findsOneWidget);
    expect(find.text('Saisissez un nombre'), findsNWidgets(3));
    expect(submitted, isNull);
  });

  testWidgets('submits a Product built from the form values', (tester) async {
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p));

    await tester.enterText(_field('name'), '  Sac de Riz  ');
    await tester.enterText(_field('purchase_price'), '4200');
    await tester.enterText(_field('sale_price'), '5000');
    await tester.enterText(_field('alert_threshold'), '3');

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.id, '');
    expect(submitted!.name, 'Sac de Riz');
    expect(submitted!.purchasePrice, 4200);
    expect(submitted!.salePrice, 5000);
    expect(submitted!.alertThreshold, 3);
    expect(submitted!.margin, 800);
    expect(submitted!.imageUrl, isNull);
  });

  testWidgets('trims and keeps a valid image URL', (tester) async {
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p));

    await tester.enterText(_field('name'), 'Sac de Riz');
    await tester.enterText(
      _field('image_url'),
      '  https://exemple.com/r.jpg  ',
    );
    await tester.enterText(_field('purchase_price'), '4200');
    await tester.enterText(_field('sale_price'), '5000');
    await tester.enterText(_field('alert_threshold'), '3');

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted!.imageUrl, 'https://exemple.com/r.jpg');
  });

  testWidgets('rejects a malformed image URL', (tester) async {
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p));

    await tester.enterText(_field('name'), 'Sac de Riz');
    await tester.enterText(_field('image_url'), 'pas une url');
    await tester.enterText(_field('purchase_price'), '4200');
    await tester.enterText(_field('sale_price'), '5000');
    await tester.enterText(_field('alert_threshold'), '3');

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(
      find.text('URL invalide (ex: https://exemple.com/photo.jpg)'),
      findsOneWidget,
    );
    expect(submitted, isNull);
  });

  testWidgets('prefills the fields when editing an existing product', (
    tester,
  ) async {
    Product? submitted;
    const existing = Product(
      id: 'abc',
      name: 'Sac de Riz',
      imageUrl: 'https://exemple.com/r.jpg',
      category: 'Alimentaire',
      unit: 'Sacs',
      purchasePrice: 4200,
      salePrice: 5000,
      quantity: 10,
      alertThreshold: 3,
    );
    await tester.pumpWidget(
      _form((p) => submitted = p, initialProduct: existing),
    );

    expect(
      tester.widget<TextFormField>(_field('image_url')).controller!.text,
      'https://exemple.com/r.jpg',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted!.id, 'abc');
    expect(submitted!.imageUrl, 'https://exemple.com/r.jpg');
  });
}
