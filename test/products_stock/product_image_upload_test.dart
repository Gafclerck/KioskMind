import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/products_stock/domain/services/product_image_upload_service.dart';
import 'package:kiosk_mind/features/products_stock/presentation/providers/product_image_upload_service_provider.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/product_form.dart';
import 'package:kiosk_mind/features/products_stock/presentation/widgets/product_image.dart';

import 'fakes.dart';

/// L'hôte de toast est monté comme dans l'application : sans lui, un toast
/// n'a nulle part où s'afficher.
Widget _form(
  void Function(Product) onSubmit, {
  Product? initialProduct,
  ProductImageUploadService? imageService,
}) => ProviderScope(
  overrides: [
    if (imageService != null)
      productImageUploadServiceProvider.overrideWithValue(imageService),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: AppToastHost(
        child: ProductForm(
          initialProduct: initialProduct,
          submitLabel: 'Enregistrer',
          isLoading: false,
          onSubmit: onSubmit,
        ),
      ),
    ),
  ),
);

Finder _button(String key) => find.byKey(ValueKey<String>('product_form_$key'));

/// Remplit les champs obligatoires pour que le submit aboutisse.
Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('product_form_name')),
    'Sac de Riz',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('product_form_purchase_price')),
    '4200',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('product_form_sale_price')),
    '5000',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('product_form_alert_threshold')),
    '3',
  );
}

void main() {
  testWidgets('uploads the picked photo and submits its URL', (tester) async {
    final service = FakeProductImageUploadService(
      urlToReturn: 'https://res.cloudinary.com/demo/image/upload/p.jpg',
    );
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p, imageService: service));

    await _fillRequiredFields(tester);
    await tester.tap(_button('pick_photo'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(
      tester
          .widget<ProductImage>(
            find.byKey(const ValueKey('product_form_photo')),
          )
          .imageUrl,
      'https://res.cloudinary.com/demo/image/upload/p.jpg',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(
      submitted!.imageUrl,
      'https://res.cloudinary.com/demo/image/upload/p.jpg',
    );
  });

  testWidgets('shows the upload progress while the request is pending', (
    tester,
  ) async {
    final service = FakeProductImageUploadService(
      completer: Completer<String?>(),
    );
    await tester.pumpWidget(_form((_) {}, imageService: service));

    await tester.tap(_button('pick_photo'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Téléversement…'), findsOneWidget);

    service.completer!.complete('https://res.cloudinary.com/demo/p.jpg');
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Changer la photo'), findsOneWidget);
  });

  testWidgets('reports an upload failure and keeps the previous photo', (
    tester,
  ) async {
    final service = FakeProductImageUploadService(
      errorToThrow: const ProductImageUploadException('Cloudinary a refusé'),
    );
    Product? submitted;
    await tester.pumpWidget(
      _form(
        (p) => submitted = p,
        imageService: service,
        initialProduct: const Product(
          id: 'abc',
          name: 'Sac de Riz',
          imageUrl: 'https://exemple.com/avant.jpg',
          category: 'Alimentaire',
          unit: 'Sacs',
          purchasePrice: 4200,
          salePrice: 5000,
          quantity: 10,
          alertThreshold: 3,
        ),
      ),
    );

    await tester.tap(_button('pick_photo'));
    await tester.pumpAndSettle();

    expect(find.text('Cloudinary a refusé'), findsOneWidget);
    expect(
      tester
          .widget<ProductImage>(
            find.byKey(const ValueKey('product_form_photo')),
          )
          .imageUrl,
      'https://exemple.com/avant.jpg',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted!.imageUrl, 'https://exemple.com/avant.jpg');
  });

  testWidgets('leaves the photo untouched when the gallery is cancelled', (
    tester,
  ) async {
    final service = FakeProductImageUploadService(urlToReturn: null);
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p, imageService: service));

    await tester.tap(_button('pick_photo'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.text('Choisir une photo'), findsOneWidget);

    await _fillRequiredFields(tester);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted!.imageUrl, isNull);
  });

  testWidgets('shows the unconfigured message when the build has no keys', (
    tester,
  ) async {
    Product? submitted;
    await tester.pumpWidget(_form((p) => submitted = p));

    await tester.tap(_button('pick_photo'));
    await tester.pumpAndSettle();

    expect(
      find.text("Le service d'images n'est pas configuré pour cette build"),
      findsOneWidget,
    );

    await _fillRequiredFields(tester);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(submitted!.imageUrl, isNull);
  });
}
