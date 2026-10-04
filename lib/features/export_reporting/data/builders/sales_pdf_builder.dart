import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../products_stock/domain/entities/product.dart';
import '../../../sales/domain/entities/sale.dart';

class SalesPdfBuilder {
  const SalesPdfBuilder();

  Future<Uint8List> build({
    required List<Sale> sales,
    required List<Product> products,
  }) async {
    final DateTime now = DateTime.now();
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              'Export des ventes',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Genere le ${_formatDate(now)} a ${_formatTime(now)}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Ventes (${sales.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const <String>[
                'Date',
                'Produit',
                'Qte',
                'PU',
                'Total',
                'Statut',
              ],
              data: _salesRows(sales),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
              ),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              columnWidths: <int, pw.TableColumnWidth>{
                4: const pw.FixedColumnWidth(55),
              },
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Produits (${products.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const <String>[
                'Nom',
                'Categorie',
                'Qte',
                'Achat',
                'Vente',
                'Marge',
              ],
              data: _productRows(products),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
              ),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  List<List<String>> _salesRows(List<Sale> sales) {
    final List<List<String>> rows = <List<String>>[];
    for (final Sale sale in sales) {
      for (final SaleItem item in sale.items) {
        rows.add(<String>[
          _formatDateTime(sale.dateTime),
          item.name,
          _number(item.qty),
          _number(item.unitPrice),
          _number(item.qty * item.unitPrice),
          _statusLabel(sale.status),
        ]);
      }
    }
    return rows;
  }

  List<List<String>> _productRows(List<Product> products) {
    return products
        .map(
          (Product product) => <String>[
            product.name,
            product.category,
            '${product.quantity}',
            '${product.purchasePrice}',
            '${product.salePrice}',
            '${product.margin}',
          ],
        )
        .toList();
  }

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${_formatTime(date)}';

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _formatTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }

  String _number(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _statusLabel(String status) {
    return switch (status) {
      'completed' => 'Payee',
      'cancelled' => 'Annulee',
      'refunded' => 'Remboursee',
      _ => status,
    };
  }
}
