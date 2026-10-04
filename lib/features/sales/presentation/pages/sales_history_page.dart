import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final getSalesHistory = ref.watch(getSalesHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        title: const Text(
          'Historique des ventes',
          style: TextStyle(
            color: Color(0xFF156C61),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(getSalesHistoryProvider);
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF156C61),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Sale>>(
        future: getSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF156C61),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Impossible de charger les ventes.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(getSalesHistoryProvider);
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final sales = _filterSales(snapshot.data ?? []);

          if (sales.isEmpty) {
            return _emptyState();
          }

          final completedSales =
              sales.where((sale) => sale.status != 'CANCELLED');

          final total = completedSales.fold<double>(
            0,
            (sum, sale) => sum + sale.total,
          );

          return RefreshIndicator(
            color: const Color(0xFF156C61),
            onRefresh: () async {
              ref.invalidate(getSalesHistoryProvider);
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _periodSelector(),
                const SizedBox(height: 16),
                _summaryCard(
                  total,
                  completedSales.length,
                ),
                const SizedBox(height: 20),
                Text(
                  '${sales.length} vente${sales.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...sales.map(
                  (sale) => _saleCard(sale),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodSelector() {
    const periods = [
      'Aujourd’hui',
      'Cette semaine',
      'Ce mois',
      'Personnalisé',
    ];

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
              selectedColor: const Color(0xFF156C61),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : const Color(0xFF156C61),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard(double total, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF156C61),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chiffre d’affaires',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatAmount(total)} FCFA',
                  style: const TextStyle(
                    color: Colors.white,
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
            color: Colors.white24,
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Ventes',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
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
    final cancelled = sale.status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                          ? Colors.red.withValues(alpha: 0.08)
                          : const Color(0xFF156C61)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      cancelled
                          ? Icons.cancel_outlined
                          : Icons.receipt_long_rounded,
                      color: cancelled
                          ? Colors.red
                          : const Color(0xFF156C61),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(sale.dateTime),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${sale.items.length} produit${sale.items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cancelled)
                    const Text(
                      'Annulée',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF156C61),
                    ),
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
                            color: Colors.grey.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatNumber(item.qty)} × ${_formatAmount(item.unitPrice)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatAmount(sale.total)} FCFA',
                    style: TextStyle(
                      color: cancelled
                          ? Colors.red
                          : const Color(0xFF156C61),
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
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Action sur la vente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF156C61),
                  ),
                  title: const Text('Modifier la vente'),
                  onTap: () {
                    Navigator.pop(context, 'edit');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  title: const Text('Annuler la vente'),
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
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UpdateSalePage(sale: sale),
        ),
      );

      if (updated == true && mounted) {
        ref.invalidate(getSalesHistoryProvider);
      }

      return;
    }

    if (action == 'cancel') {
      await _cancelSale(sale);
    }
  }

  Future<void> _cancelSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Annuler la vente ?'),
          content: const Text(
            'Cette action annulera la vente et restaurera automatiquement le stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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

      ref.invalidate(getSalesHistoryProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vente annulée avec succès'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’annuler la vente'),
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
        final startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));

        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        final end = start.add(const Duration(days: 7));

        return sales.where((sale) {
          return !sale.dateTime.isBefore(start) &&
              sale.dateTime.isBefore(end);
        }).toList();

      case 'Ce mois':
        final start = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1);

        return sales.where((sale) {
          return !sale.dateTime.isBefore(start) &&
              sale.dateTime.isBefore(end);
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
          return !sale.dateTime.isBefore(start) &&
              sale.dateTime.isBefore(end);
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

  Widget _emptyState() {
    return const Center(
      child: Text(
        'Aucune vente',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
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

  String _formatAmount(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }
}