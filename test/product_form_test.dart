import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/product_form.dart';

Widget _form(void Function(Product) onSubmit) => MaterialApp(
  home: Scaffold(
    body: ProductForm(
      submitLabel: 'Enregistrer',
      isLoading: false,
      onSubmit: onSubmit,
    ),
  ),
);

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

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Sac de Riz  ');
    await tester.enterText(fields.at(1), '4200');
    await tester.enterText(fields.at(2), '5000');
    await tester.enterText(fields.at(3), '3');

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.id, '');
    expect(submitted!.name, 'Sac de Riz');
    expect(submitted!.purchasePrice, 4200);
    expect(submitted!.salePrice, 5000);
    expect(submitted!.alertThreshold, 3);
    expect(submitted!.margin, 800);
  });
}
