import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../products_stock/domain/entities/product.dart';
import '../../../products_stock/presentation/providers/product_providers.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../domain/models/export_format.dart';
import '../providers/export_providers.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportFormat? _exporting;

  Future<void> _export(ExportFormat format) async {
    if (_exporting != null) {
      return;
    }
    final List<Sale>? sales = ref.read(salesForExportProvider).valueOrNull;
    final List<Product>? products = ref.read(productsProvider).valueOrNull;
    if (sales == null) {
      return;
    }
    setState(() => _exporting = format);
    try {
      final file = await ref
          .read(salesExportGeneratorProvider)
          .generateSalesExport(
            sales: sales,
            products: products ?? const <Product>[],
            format: format,
          );
      await ref.read(shareExportGatewayProvider).share(file);
      if (!mounted) {
        return;
      }
      AppToast.show(
        ref,
        message: 'Export ${format.label} partagé',
        type: AppToastType.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        ref,
        message: "Impossible d'exporter les données, réessayez",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Sale>> salesAsync = ref.watch(salesForExportProvider);
    final AsyncValue<List<Product>> productsAsync = ref.watch(productsProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final int salesCount = salesAsync.valueOrNull?.length ?? 0;
    final int productsCount = productsAsync.valueOrNull?.length ?? 0;
    final bool isLoading =
        salesAsync.isLoading || productsAsync.isLoading || _exporting != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Export des données')),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceBright,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contenu de l\u2019export',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ventes enregistrées : $salesCount',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Produits au catalogue : $productsCount',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Le fichier est généré puis partagé avec l’application '
                    'de votre choix (e-mail, Drive, messages…).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Format',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ExportTile(
              icon: Icons.table_chart_outlined,
              title: 'Tableur (CSV)',
              subtitle: 'Recommandé pour Excel et LibreOffice',
              isLoading: _exporting == ExportFormat.csv,
              enabled: !isLoading && salesCount > 0,
              onTap: _export,
              format: ExportFormat.csv,
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            _ExportTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Document (PDF)',
              subtitle: 'Un rapport lisible et imprimable',
              isLoading: _exporting == ExportFormat.pdf,
              enabled: !isLoading && salesCount > 0,
              onTap: _export,
              format: ExportFormat.pdf,
              scheme: scheme,
            ),
            if (salesCount == 0) ...[
              const SizedBox(height: 12),
              Text(
                'Aucune vente à exporter pour le moment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
    required this.format,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<ExportFormat> onTap;
  final ExportFormat format;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceBright,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? () => onTap(format) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                FilledButton.tonal(
                  onPressed: enabled ? () => onTap(format) : null,
                  child: const Text('Exporter'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
