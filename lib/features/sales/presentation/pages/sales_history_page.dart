import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';
import '../../../../core/theme/app_colors.dart';

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
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Historique des ventes',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ),
      body: FutureBuilder<List<Sale>>(
        future: getSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

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
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(getSalesHistoryProvider);
              setState(() {});

              await Future.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                32,
              ),
              children: [
                _PeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onChanged: _handlePeriodChanged,
                ),

                if (selectedPeriod == 'Personnalisé' &&
                    selectedDateRange != null) ...[
                  const SizedBox(height: 14),
                  _SelectedDateRangeCard(
                    dateRange: selectedDateRange!,
                    onChange: _selectCustomDateRange,
                  ),
                ],

                const SizedBox(height: 20),

                _SalesSummaryCard(
                  total: total,
                  salesCount: sales.length,
                  topProduct: topProduct,
                  period: _getPeriodLabel(),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Détails des ventes',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (sales.isEmpty)
                  _EmptyState(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  )
                else
                  ...sales.map(
                    (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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

  String _getTopProduct(List<Sale> sales) {
    final quantities = <String, double>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        quantities[item.name] =
            (quantities[item.name] ?? 0) + item.qty;
      }
    }

    if (quantities.isEmpty) {
      return 'Aucun produit';
    }

    final top = quantities.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return top.key;
  }

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
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = periods[index];
          final selected = period == selectedPeriod;

          return ChoiceChip(
            label: Text(period),
            selected: selected,
            onSelected: (_) => onChanged(period),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.lightSurface,
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondaryLight
                      .withValues(alpha: 0.25),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            labelStyle: textTheme.labelMedium?.copyWith(
              color: selected
                  ? Colors.white
                  : AppColors.textPrimaryLight,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// PÉRIODE PERSONNALISÉE
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: InkWell(
        onTap: onChange,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Période sélectionnée',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(dateRange.start)} → '
                      '${_formatDate(dateRange.end)}',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_rounded,
                size: 22,
                color: AppColors.secondary,
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total des ventes',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$salesCount vente${salesCount > 1 ? 's' : ''}',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            period,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            '${_formatAmount(total)} FCFA',
            style: textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 18),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 19,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produit le plus vendu',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topProduct,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
    final textTheme = Theme.of(context).textTheme;
    final isCancelled = sale.status == 'CANCELLED';

    final productSummary = sale.items
        .map(
          (item) =>
              '${_formatQuantity(item.qty)} ${item.name}',
        )
        .join(', ');

    final iconColor = isCancelled
        ? AppColors.error
        : AppColors.primary;

    final iconBackground = isCancelled
        ? AppColors.error.withValues(alpha: 0.10)
        : AppColors.primary.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isCancelled
                    ? Icons.receipt_long_rounded
                    : Icons.receipt_long_rounded,
                size: 25,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(sale.dateTime),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (isCancelled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Annulée',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${_formatAmount(sale.total)} FCFA',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isCancelled
                    ? AppColors.error
                    : AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Aucune vente pour cette période',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Les ventes enregistrées apparaîtront ici.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Impossible de charger les ventes',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Vérifiez votre connexion et réessayez.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}