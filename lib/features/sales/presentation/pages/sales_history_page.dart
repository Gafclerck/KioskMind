import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/money.dart';
import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';
import 'update_sale_page.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  String _selectedPeriod = 'Aujourd’hui';

  DateTime? _customStart;
  DateTime? _customEnd;

  Future<void> _refresh() async {
    ref.invalidate(salesHistoryStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(salesHistoryStreamProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Historique des ventes',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Text(
              'Impossible de charger les ventes.',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          );
        },
        data: (allSales) {
          final sales = _filterSales(allSales);

          final completedSales = sales.where(
            (sale) => sale.status != 'CANCELLED',
          );

          final total = completedSales.fold<double>(
            0,
            (sum, sale) => sum + sale.total,
          );

          return RefreshIndicator(
            color: colorScheme.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _periodSelector(),
                const SizedBox(height: 16),
                _summaryCard(total, completedSales.length),
                const SizedBox(height: 20),
                if (sales.isEmpty)
                  _emptyState(hasAnySales: allSales.isNotEmpty)
                else ...[
                  Text(
                    '${sales.length} vente${sales.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sales.map((sale) => _saleCard(sale)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodSelector() {
    final colorScheme = Theme.of(context).colorScheme;

    const periods = ['Aujourd’hui', 'Cette semaine', 'Ce mois', 'Personnalisé'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final selected = period == _selectedPeriod;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: selected,
              onSelected: (_) async {
                if (period == 'Personnalisé') {
                  await _selectCustomPeriod();
                } else {
                  setState(() {
                    _selectedPeriod = period;
                  });
                }
              },
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainer,
              side: BorderSide(color: colorScheme.outlineVariant),
              labelStyle: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard(double total, int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chiffre d’affaires',
                  style: TextStyle(
                    color: colorScheme.onPrimary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatAmount(total)} FCFA',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: colorScheme.onPrimary.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Ventes',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saleCard(Sale sale) {
    final colorScheme = Theme.of(context).colorScheme;
    final cancelled = sale.status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: cancelled ? null : () => _showSaleActions(sale),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cancelled
                          ? colorScheme.error.withValues(alpha: 0.08)
                          : colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      cancelled
                          ? Icons.cancel_outlined
                          : Icons.receipt_long_rounded,
                      color: cancelled
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(sale.dateTime),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${sale.items.length} produit${sale.items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cancelled)
                    Text(
                      'Annulée',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Icon(Icons.more_vert_rounded, color: colorScheme.primary),
                ],
              ),
              const SizedBox(height: 14),
              ...sale.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatNumber(item.qty)} × ${_formatAmount(item.unitPrice)}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 20, color: colorScheme.outlineVariant),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatAmount(sale.total)} FCFA',
                    style: TextStyle(
                      color: cancelled
                          ? colorScheme.error
                          : colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSaleActions(Sale sale) async {
    final colorScheme = Theme.of(context).colorScheme;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sheetColorScheme = Theme.of(context).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetColorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Action sur la vente',
                  style: TextStyle(
                    color: sheetColorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: sheetColorScheme.primary,
                  ),
                  title: Text(
                    'Modifier la vente',
                    style: TextStyle(color: sheetColorScheme.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(context, 'edit');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.cancel_outlined,
                    color: sheetColorScheme.error,
                  ),
                  title: Text(
                    'Annuler la vente',
                    style: TextStyle(color: sheetColorScheme.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(context, 'cancel');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => UpdateSalePage(sale: sale)),
      );

      return;
    }

    if (action == 'cancel') {
      await _cancelSale(sale);
    }
  }

  Future<void> _cancelSale(Sale sale) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: Text(
            'Annuler la vente ?',
            style: TextStyle(color: dialogColorScheme.onSurface),
          ),
          content: Text(
            'Cette action annulera la vente et restaurera automatiquement le stock.',
            style: TextStyle(color: dialogColorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: dialogColorScheme.onError,
              ),
              child: const Text('Annuler la vente'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(cancelSaleProvider)(sale.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vente annulée avec succès'),
          backgroundColor: colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible d’annuler la vente'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  List<Sale> _filterSales(List<Sale> sales) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Aujourd’hui':
        return sales.where((sale) {
          return sale.dateTime.year == now.year &&
              sale.dateTime.month == now.month &&
              sale.dateTime.day == now.day;
        }).toList();

      case 'Cette semaine':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        final end = start.add(const Duration(days: 7));

        return sales.where((sale) {
          return !sale.dateTime.isBefore(start) && sale.dateTime.isBefore(end);
        }).toList();

      case 'Ce mois':
        final start = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1);

        return sales.where((sale) {
          return !sale.dateTime.isBefore(start) && sale.dateTime.isBefore(end);
        }).toList();

      case 'Personnalisé':
        if (_customStart == null || _customEnd == null) {
          return sales;
        }

        final start = DateTime(
          _customStart!.year,
          _customStart!.month,
          _customStart!.day,
        );

        final end = DateTime(
          _customEnd!.year,
          _customEnd!.month,
          _customEnd!.day + 1,
        );

        return sales.where((sale) {
          return !sale.dateTime.isBefore(start) && sale.dateTime.isBefore(end);
        }).toList();

      default:
        return sales;
    }
  }

  Future<void> _selectCustomPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedPeriod = 'Personnalisé';
      _customStart = picked.start;
      _customEnd = picked.end;
    });
  }

  Widget _emptyState({required bool hasAnySales}) {
    final colorScheme = Theme.of(context).colorScheme;

    final String message;

    if (!hasAnySales) {
      message = 'Aucune vente enregistrée';
    } else {
      switch (_selectedPeriod) {
        case 'Aujourd’hui':
          message = 'Il n’y a pas encore eu de vente aujourd’hui.';
          break;

        case 'Cette semaine':
          message = 'Il n’y a pas encore eu de vente cette semaine.';
          break;

        case 'Ce mois':
          message = 'Il n’y a pas encore eu de vente ce mois-ci.';
          break;

        case 'Personnalisé':
          message = 'Il n’y a pas de vente pour cette période.';
          break;

        default:
          message = 'Aucune vente pour cette période.';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasAnySales
                ? 'Sélectionnez une autre période (Cette semaine, Ce mois...) pour voir vos autres ventes.'
                : 'Vos ventes enregistrées apparaîtront ici.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatAmount(double value) => formatThousands(value);
}
