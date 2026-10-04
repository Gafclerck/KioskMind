import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../data/gateways/share_plus_export_gateway.dart';
import '../../data/generators/sales_export_generator_impl.dart';
import '../../data/builders/sales_csv_builder.dart';
import '../../data/builders/sales_pdf_builder.dart';
import '../../domain/services/export_generator.dart';
import '../../domain/services/share_export_gateway.dart';

final salesExportGeneratorProvider = Provider<ExportGenerator>((ref) {
  return SalesExportGeneratorImpl(
    csvBuilder: const SalesCsvBuilder(),
    pdfBuilder: const SalesPdfBuilder(),
  );
});

final shareExportGatewayProvider = Provider<ShareExportGateway>(
  (ref) => const SharePlusExportGateway(),
);

/// Ventilation des ventes pour l'export, réutilisant [GetSalesHistory].
final salesForExportProvider = FutureProvider.autoDispose<List<Sale>>((ref) {
  return ref.watch(getSalesHistoryProvider)();
});
