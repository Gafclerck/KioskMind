import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/export_reporting/data/builders/sales_csv_builder.dart';
import 'package:kiosk_mind/features/export_reporting/data/builders/sales_pdf_builder.dart';
import 'package:kiosk_mind/features/export_reporting/data/generators/sales_export_generator_impl.dart';
import 'package:kiosk_mind/features/export_reporting/domain/models/export_format.dart';
import 'package:kiosk_mind/features/products_stock/domain/entities/product.dart';
import 'package:kiosk_mind/features/sales/domain/entities/sale.dart';

final RegExp _stampPattern = RegExp(
  r'^kioskmind_ventes_\d{8}_\d{6}\.(csv|pdf)$',
);

void main() {
  final Sale sale = Sale(
    id: 's1',
    dateTime: DateTime(2026, 5, 12, 14, 30),
    createdAt: DateTime(2026, 5, 12, 14, 30),
    total: 375.0,
    source: 'kiosk',
    status: 'completed',
    items: [SaleItem(productId: 'p1', name: 'Riz 5kg', qty: 1, unitPrice: 250)],
  );
  const Product product = Product(
    id: 'p3',
    name: 'Sucre 1kg',
    category: 'Épicerie',
    unit: 'kg',
    purchasePrice: 600,
    salePrice: 750,
    quantity: 40,
    alertThreshold: 5,
  );
  final SalesExportGeneratorImpl generator = SalesExportGeneratorImpl(
    csvBuilder: const SalesCsvBuilder(),
    pdfBuilder: const SalesPdfBuilder(),
  );

  test(
    'builds a UTF-8 CSV file with the expected name and mime type',
    () async {
      final file = await generator.generateSalesExport(
        sales: [sale],
        products: [product],
        format: ExportFormat.csv,
      );

      expect(file.mimeType, 'text/csv');
      expect(_stampPattern.hasMatch(file.filename), isTrue);
      expect(file.filename.endsWith('.csv'), isTrue);
      final String content = utf8.decode(file.bytes);
      expect(content, contains('Date;Produit;Quantite'));
      expect(content, contains('Riz 5kg'));
      expect(content, contains('Sucre 1kg'));
      expect(content, contains('Épicerie'));
    },
  );

  test('builds a PDF file with the expected name and mime type', () async {
    final file = await generator.generateSalesExport(
      sales: [sale],
      products: [product],
      format: ExportFormat.pdf,
    );

    expect(file.mimeType, 'application/pdf');
    expect(_stampPattern.hasMatch(file.filename), isTrue);
    expect(file.filename.endsWith('.pdf'), isTrue);
    expect(file.bytes.length, greaterThan(100));
    expect(utf8.decode(file.bytes.sublist(0, 5)), '%PDF-');
  });
}
