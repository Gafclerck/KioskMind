import '../../../../../core/errors/failure.dart';
import '../../../../../core/usecase/result.dart';
import '../../../../export_reporting/domain/models/export_file.dart';
import '../../../../export_reporting/domain/models/export_format.dart';
import '../../../../export_reporting/domain/services/export_generator.dart';
import '../../../../export_reporting/domain/services/share_export_gateway.dart';
import '../../../../products_stock/domain/entities/product.dart';
import '../../../../products_stock/domain/repositories/product_repository.dart';
import '../../../../sales/domain/entities/sale.dart';
import '../../../../sales/domain/usecases/get_sales_history.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';

/// Real handler for generating and sharing sales export reports.
final class RealExportReportHandler implements ExportSalesReportHandler {
  RealExportReportHandler({
    required this.exportGenerator,
    required this.shareGateway,
    required this.getSalesHistory,
    required this.productRepository,
  });

  final ExportGenerator exportGenerator;
  final ShareExportGateway shareGateway;
  final GetSalesHistory getSalesHistory;
  final ProductRepository productRepository;

  @override
  String get intentId => 'export_sales_report';

  @override
  Future<Result<ExportSalesReportResult>> execute(
    CommandContext context,
    ExportSalesReportInput input,
  ) async {
    final ExportFormat format = input.format.toLowerCase() == 'csv'
        ? ExportFormat.csv
        : ExportFormat.pdf;

    try {
      final List<Sale> sales = await getSalesHistory();
      final List<Product> products = await productRepository.getProducts();

      final ExportFile file = await exportGenerator.generateSalesExport(
        sales: sales,
        products: products,
        format: format,
      );

      await shareGateway.share(file);

      return Success<ExportSalesReportResult>((
        format: format.label,
        filePath: file.filename,
        salesCount: sales.length,
      ));
    } catch (e) {
      return Failed<ExportSalesReportResult>(ExportFailed(e.toString()));
    }
  }
}
