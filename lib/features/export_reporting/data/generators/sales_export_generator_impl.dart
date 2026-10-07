import 'dart:convert';
import 'dart:typed_data';

import '../../../products_stock/domain/entities/product.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../domain/models/export_file.dart';
import '../../domain/models/export_format.dart';
import '../../domain/services/export_generator.dart';
import '../builders/sales_csv_builder.dart';
import '../builders/sales_pdf_builder.dart';

class SalesExportGeneratorImpl implements ExportGenerator {
  SalesExportGeneratorImpl({
    required this.csvBuilder,
    required this.pdfBuilder,
  });

  final SalesCsvBuilder csvBuilder;
  final SalesPdfBuilder pdfBuilder;

  @override
  Future<ExportFile> generateSalesExport({
    required List<Sale> sales,
    required List<Product> products,
    required ExportFormat format,
  }) async {
    final String stamp = _timestamp();
    return switch (format) {
      ExportFormat.csv => ExportFile(
        bytes: Uint8List.fromList(
          utf8.encode(csvBuilder.build(sales: sales, products: products)),
        ),
        filename: 'kioskmind_ventes_$stamp.csv',
        mimeType: 'text/csv',
      ),
      ExportFormat.pdf => ExportFile(
        bytes: await pdfBuilder.build(sales: sales, products: products),
        filename: 'kioskmind_ventes_$stamp.pdf',
        mimeType: 'application/pdf',
      ),
    };
  }

  String _timestamp() {
    String two(int value) => value.toString().padLeft(2, '0');
    final DateTime now = DateTime.now();
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
