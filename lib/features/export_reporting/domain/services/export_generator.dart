import '../../../products_stock/domain/entities/product.dart';
import '../../../sales/domain/entities/sale.dart';
import '../models/export_file.dart';
import '../models/export_format.dart';

/// Fabrique un fichier d'export des ventes et du stock.
abstract interface class ExportGenerator {
  Future<ExportFile> generateSalesExport({
    required List<Sale> sales,
    required List<Product> products,
    required ExportFormat format,
  });
}
