import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() =>
      _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  String selectedPeriod = 'Cette semaine';
  DateTimeRange? selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final getSalesHistory = ref.watch(getSalesHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Ventes'),
      ),
      body: FutureBuilder<List<Sale>>(
        future: getSalesHistory(),
        builder: (context, snapshot) {
          // État de chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          // État d'erreur
          if (snapshot.hasError) {
            return _ErrorState(
              colorScheme: colorScheme,
              textTheme: textTheme,
              onRetry: () {
                ref.invalidate(getSalesHistoryProvider);
                setState(() {});
              },
            );
          }

          final allSales = snapshot.data ?? [];

          final sales = _filterSales(allSales);

          final total = sales.fold<double>(
            0,
            (sum, sale) => sum + sale.total,
          );

          final topProduct = _getTopProduct(sales);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(getSalesHistoryProvider);

              setState(() {});

              await Future.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                32,
              ),
              children: [
                // Sélection de la période
                _PeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onChanged: _handlePeriodChanged,
                ),

                // Période personnalisée
                if (selectedPeriod == 'Personnalisé' &&
                    selectedDateRange != null) ...[
                  const SizedBox(height: 10),
                  _SelectedDateRangeCard(
                    dateRange: selectedDateRange!,
                    onChange: _selectCustomDateRange,
                  ),
                ],

                const SizedBox(height: 12),

                // Résumé des ventes
                _SalesSummaryCard(
                  total: total,
                  salesCount: sales.length,
                  topProduct: topProduct,
                  period: _getPeriodLabel(),
                ),

                const SizedBox(height: 24),

                Text(
                  'Détails des Ventes',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                // État vide / liste des ventes
                if (sales.isEmpty)
                  _EmptyState(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  )
                else
                  ...sales.map(
                    (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SaleCard(
                        sale: sale,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHANGEMENT DE PÉRIODE
  // ---------------------------------------------------------------------------

  Future<void> _handlePeriodChanged(String period) async {
    if (period == 'Personnalisé') {
      setState(() {
        selectedPeriod = period;
      });

      await _selectCustomDateRange();
      return;
    }

    setState(() {
      selectedPeriod = period;
      selectedDateRange = null;
    });
  }

  // ---------------------------------------------------------------------------
  // SÉLECTION D'UNE PÉRIODE PERSONNALISÉE
  // ---------------------------------------------------------------------------

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();

    final initialRange = selectedDateRange ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            1,
          ),
          end: now,
        );

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
      helpText: 'Sélectionner une période',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      fieldStartLabelText: 'Début',
      fieldEndLabelText: 'Fin',
    );

    if (pickedRange == null) {
      // Si aucune période n'avait encore été choisie,
      // on revient à "Cette semaine".
      if (selectedDateRange == null) {
        setState(() {
          selectedPeriod = 'Cette semaine';
        });
      }

      return;
    }

    setState(() {
      selectedDateRange = DateTimeRange(
        start: DateTime(
          pickedRange.start.year,
          pickedRange.start.month,
          pickedRange.start.day,
        ),
        end: DateTime(
          pickedRange.end.year,
          pickedRange.end.month,
          pickedRange.end.day,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // FILTRAGE DES VENTES
  // ---------------------------------------------------------------------------

  List<Sale> _filterSales(List<Sale> sales) {
    final now = DateTime.now();

    DateTime? startDate;
    DateTime? endDate;

    switch (selectedPeriod) {
      case 'Aujourd’hui':
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        );

        endDate = startDate.add(
          const Duration(days: 1),
        );
        break;

      case 'Cette semaine':
        final daysFromMonday = now.weekday - 1;

        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(
          Duration(days: daysFromMonday),
        );

        endDate = startDate.add(
          const Duration(days: 7),
        );
        break;

      case 'Ce mois':
        startDate = DateTime(
          now.year,
          now.month,
          1,
        );

        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        );
        break;

      case 'Personnalisé':
        if (selectedDateRange == null) {
          return [];
        }

        startDate = DateTime(
          selectedDateRange!.start.year,
          selectedDateRange!.start.month,
          selectedDateRange!.start.day,
        );

        // + 1 jour pour inclure toute la journée de fin.
        endDate = DateTime(
          selectedDateRange!.end.year,
          selectedDateRange!.end.month,
          selectedDateRange!.end.day,
        ).add(
          const Duration(days: 1),
        );
        break;

      default:
        return sales;
    }

    return sales.where((sale) {
      return !sale.dateTime.isBefore(startDate!) &&
          sale.dateTime.isBefore(endDate!);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // PRODUIT LE PLUS VENDU
  // ---------------------------------------------------------------------------

  String _getTopProduct(List<Sale> sales) {
    final quantities = <String, double>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        quantities[item.name] =
            (quantities[item.name] ?? 0) + item.qty;
      }
    }

    if (quantities.isEmpty) {
      return 'Aucun';
    }

    final top = quantities.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return top.key;
  }

  // ---------------------------------------------------------------------------
  // LABEL DE LA PÉRIODE
  // ---------------------------------------------------------------------------

  String _getPeriodLabel() {
    if (selectedPeriod != 'Personnalisé' ||
        selectedDateRange == null) {
      return selectedPeriod;
    }

    return '${_formatDate(selectedDateRange!.start)} - '
        '${_formatDate(selectedDateRange!.end)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// =============================================================================
// SÉLECTEUR DE PÉRIODE
// =============================================================================

class _PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  static const periods = [
    'Aujourd’hui',
    'Cette semaine',
    'Ce mois',
    'Personnalisé',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final period = periods[index];
          final selected = period == selectedPeriod;

          return ChoiceChip(
            label: Text(period),
            selected: selected,
            onSelected: (_) => onChanged(period),
            selectedColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
            labelStyle: textTheme.labelSmall?.copyWith(
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
              fontWeight: selected
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// CARTE PÉRIODE PERSONNALISÉE
// =============================================================================

class _SelectedDateRangeCard extends StatelessWidget {
  final DateTimeRange dateRange;
  final VoidCallback onChange;

  const _SelectedDateRangeCard({
    required this.dateRange,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onChange,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Période sélectionnée',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatDate(dateRange.start)} → '
                      '${_formatDate(dateRange.end)}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_calendar_outlined,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// =============================================================================
// RÉSUMÉ DES VENTES
// =============================================================================

class _SalesSummaryCard extends StatelessWidget {
  final double total;
  final int salesCount;
  final String topProduct;
  final String period;

  const _SalesSummaryCard({
    required this.total,
    required this.salesCount,
    required this.topProduct,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Ventes $period',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$salesCount vente${salesCount > 1 ? 's' : ''}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatAmount(total)} FCFA',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.star_outline,
                size: 16,
                color: colorScheme.onPrimary.withValues(
                  alpha: 0.85,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Top produit : $topProduct',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }
}

// =============================================================================
// CARTE D'UNE VENTE
// =============================================================================

class _SaleCard extends StatelessWidget {
  final Sale sale;

  const _SaleCard({
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isCancelled = sale.status == 'CANCELLED';

    final productSummary = sale.items
        .map(
          (item) =>
              '${_formatQuantity(item.qty)} ${item.name}',
        )
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCancelled
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 19,
                color: isCancelled
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTime(sale.dateTime),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isCancelled) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• Annulée',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatAmount(sale.total)} F',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isCancelled
                    ? colorScheme.error
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString();
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(double amount) {
    return amount.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }
}

// =============================================================================
// ÉTAT VIDE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _EmptyState({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune vente pour cette période',
              textAlign: TextAlign.center,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Les ventes enregistrées apparaîtront ici.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ÉTAT ERREUR
// =============================================================================

class _ErrorState extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.colorScheme,
    required this.textTheme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les ventes.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}