import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_routes.dart';
import '../../../../features/products_stock/presentation/providers/product_providers.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';

enum _Period { jour, semaine, mois }

class _P {
  final ColorScheme cs;
  final TextTheme t;
  final bool dark;

  _P._(this.cs, this.t, this.dark);

  factory _P.of(BuildContext context) {
    final theme = Theme.of(context);

    return _P._(
      theme.colorScheme,
      theme.textTheme,
      theme.brightness == Brightness.dark,
    );
  }

  Color get card => cs.surfaceBright;
  Color get border => cs.outlineVariant;
  Color get text => cs.onSurface;
  Color get muted => cs.onSurfaceVariant;
  Color get primary => cs.primary;
  Color get onPrimary => cs.onPrimary;
  Color get soft => cs.primaryContainer;
  Color get onSoft => cs.onPrimaryContainer;
  Color get error => cs.error;
  Color get errorSoft => cs.errorContainer;
  Color get accent => cs.secondary;
  Color get info => AppColors.info;

  Color get success => dark ? AppColors.successDark : AppColors.successLight;

  BoxDecoration get cardDecoration => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
  );
}

// -----------------------------------------------------------------------------
// DASHBOARD
// -----------------------------------------------------------------------------

class SalesDashboardPage extends ConsumerStatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  ConsumerState<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends ConsumerState<SalesDashboardPage> {
  late Future<List<Sale>> _future;

  _Period _period = _Period.semaine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(getSalesHistoryProvider).call();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  String _getUserFirstName(String? fullName) {
    final name = fullName?.trim() ?? '';

    if (name.isEmpty) {
      return 'Utilisateur';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  DateTimeRange _currentRange(_Period period) {
    final now = DateTime.now();

    switch (period) {
      case _Period.jour:
        final start = DateTime(now.year, now.month, now.day);

        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 1)),
        );

      case _Period.semaine:
        final today = DateTime(now.year, now.month, now.day);
        final daysFromMonday = today.weekday - 1;
        final start = today.subtract(Duration(days: daysFromMonday));

        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );

      case _Period.mois:
        final start = DateTime(now.year, now.month, 1);

        return DateTimeRange(
          start: start,
          end: DateTime(now.year, now.month + 1, 1),
        );
    }
  }

  DateTimeRange _previousRange(_Period period) {
    final current = _currentRange(period);
    final duration = current.end.difference(current.start);

    return DateTimeRange(
      start: current.start.subtract(duration),
      end: current.start,
    );
  }

  List<Sale> _filterSales(List<Sale> sales, DateTimeRange range) {
    return sales.where((sale) {
      return !sale.dateTime.isBefore(range.start) &&
          sale.dateTime.isBefore(range.end);
    }).toList();
  }

  bool _isCancelled(Sale sale) {
    return sale.status.toUpperCase() == 'CANCELLED';
  }

  List<Sale> _validSales(List<Sale> sales) {
    return sales.where((sale) => !_isCancelled(sale)).toList();
  }

  double _totalRevenue(List<Sale> sales) {
    return _validSales(sales).fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
  }

  double _totalCost(List<Sale> sales) {
    var total = 0.0;

    for (final sale in _validSales(sales)) {
      for (final item in sale.items) {
        final unitCost = item.unitCost ?? 0;

        total += item.qty * unitCost;
      }
    }

    return total;
  }

  (List<String>, List<double>) _buildChart(List<Sale> sales) {
    final validSales = _validSales(sales);

    switch (_period) {
      case _Period.jour:
        final labels = ['00h', '04h', '08h', '12h', '16h', '20h', '24h'];

        final values = List<double>.filled(7, 0);

        for (final sale in validSales) {
          final hour = sale.dateTime.hour;

          var index = hour ~/ 4;

          if (index < 0) {
            index = 0;
          }

          if (index > 5) {
            index = 6;
          }

          values[index] += sale.total;
        }

        return (labels, values);

      case _Period.semaine:
        final labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

        final values = List<double>.filled(7, 0);

        for (final sale in validSales) {
          final index = sale.dateTime.weekday - 1;

          if (index >= 0 && index < 7) {
            values[index] += sale.total;
          }
        }

        return (labels, values);

      case _Period.mois:
        final labels = ['S1', 'S2', 'S3', 'S4'];

        final values = List<double>.filled(4, 0);

        for (final sale in validSales) {
          final day = sale.dateTime.day;

          var index = (day - 1) ~/ 7;

          if (index > 3) {
            index = 3;
          }

          values[index] += sale.total;
        }

        return (labels, values);
    }
  }

  Map<String, double> _productQuantities(List<Sale> sales) {
    final quantities = <String, double>{};

    for (final sale in _validSales(sales)) {
      for (final item in sale.items) {
        quantities[item.name] = (quantities[item.name] ?? 0) + item.qty;
      }
    }

    return quantities;
  }

  Map<String, double> _categoryQuantities(
    List<Sale> sales,
    List<dynamic> products,
  ) {
    final quantities = _productQuantities(sales);

    final categories = <String, double>{};

    for (final entry in quantities.entries) {
      String category = 'Autres';

      for (final product in products) {
        if (product.name == entry.key) {
          category = product.category;
          break;
        }
      }

      categories[category] = (categories[category] ?? 0) + entry.value;
    }

    return categories;
  }

  String _peakHour(List<Sale> sales) {
    final validSales = _validSales(sales);

    if (validSales.isEmpty) {
      return 'Aucune donnée';
    }

    final hourly = <int, double>{};

    for (final sale in validSales) {
      final hour = sale.dateTime.hour;

      hourly[hour] = (hourly[hour] ?? 0) + sale.total;
    }

    if (hourly.isEmpty) {
      return 'Aucune donnée';
    }

    final peak = hourly.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final startHour = peak.key;
    final endHour = startHour + 1;

    return '${startHour.toString().padLeft(2, '0')}h00 - '
        '${endHour.toString().padLeft(2, '0')}h00';
  }

  double _growth(List<Sale> current, List<Sale> previous) {
    final currentRevenue = _totalRevenue(current);
    final previousRevenue = _totalRevenue(previous);

    if (previousRevenue == 0) {
      if (currentRevenue == 0) {
        return 0;
      }

      return 100;
    }

    return ((currentRevenue - previousRevenue) / previousRevenue) * 100;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final productsAsync = ref.watch(productsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Sale>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: p.primary),
              );
            }

            if (snap.hasError || !snap.hasData) {
              return _ErrorState(
                message: 'Impossible de charger les statistiques.',
                onRetry: _refresh,
              );
            }

            final allSales = snap.data ?? [];

            final todayRange = _currentRange(_Period.jour);
            final todaySales = _filterSales(allSales, todayRange);

            final currentRange = _currentRange(_period);
            final currentSales = _filterSales(allSales, currentRange);

            final previousRange = _previousRange(_period);
            final previousSales = _filterSales(allSales, previousRange);

            final revenue = _totalRevenue(todaySales);
            final cost = _totalCost(todaySales);
            final margin = revenue - cost;

            final validTodaySales = _validSales(todaySales);

            final basket = validTodaySales.isNotEmpty
                ? revenue / validTodaySales.length
                : 0.0;

            final growth = _growth(currentSales, previousSales);

            final (labels, values) = _buildChart(currentSales);

            final products = productsAsync.valueOrNull ?? [];

            final totalUnits = products.fold<int>(
              0,
              (sum, product) => sum + product.quantity,
            );

            final categoriesCount = products
                .map((product) => product.category.trim())
                .where((category) => category.isNotEmpty)
                .toSet()
                .length;

            final alertProducts =
                products
                    .where(
                      (product) => product.quantity <= product.alertThreshold,
                    )
                    .toList()
                  ..sort((a, b) => a.quantity.compareTo(b.quantity));

            final alertCount = alertProducts.length;

            final productQuantities = _productQuantities(currentSales);

            final categoryQuantities = _categoryQuantities(
              currentSales,
              products,
            );

            final bestProduct = productQuantities.isEmpty
                ? 'Aucun produit'
                : (productQuantities.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .first
                    .key;

            final peakHour = _peakHour(currentSales);

            return RefreshIndicator(
              onRefresh: _refresh,
              color: p.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // HEADER
                  _Header(
                    name: _getUserFirstName(
                      profileAsync.valueOrNull?.fullName,
                    ),
                    alertCount: alertCount,
                  ),

                  const SizedBox(height: 20),

                  // KPI
                  _KpiGrid(
                    revenue: revenue,
                    margin: margin,
                    totalUnits: totalUnits,
                    categoriesCount: categoriesCount,
                    basket: basket,
                    alertCount: alertCount,
                    growth: _growth(
                      todaySales,
                      _filterSales(
                        allSales,
                        _previousRange(_Period.jour),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ACTIONS RAPIDES
                  _SectionTitle('Actions rapides', p),

                  const SizedBox(height: 12),

                  _QuickActions(
                    onAddProduct: () {
                      try {
                        context.push(AppRoutes.addProduct);
                      } catch (_) {
                        _toast('Ajouter produit');
                      }
                    },
                    onNewSale: () {
                      try {
                        context.push(AppRoutes.createSale);
                      } catch (_) {
                        _toast('Nouvelle vente');
                      }
                    },
                    onScan: () {
                      _toast('Scanner bientôt disponible');
                    },
                  ),

                  const SizedBox(height: 24),

                  // STATISTIQUES
                  _SectionTitle('Statistiques', p),

                  const SizedBox(height: 12),

                  _PeriodSelector(
                    value: _period,
                    onChanged: (value) {
                      setState(() {
                        _period = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // GRAPHIQUE
                  _SalesChartCard(
                    labels: labels,
                    values: values,
                  ),

                  const SizedBox(height: 12),

                  // CATEGORIES
                  _CategoriesCard(
                    quantities: categoryQuantities,
                  ),

                  const SizedBox(height: 12),

                  // TOP PRODUITS
                  _TopProductsCard(
                    qty: productQuantities,
                  ),

                  const SizedBox(height: 12),

                  // INSIGHTS
                  _InsightsRow(
                    bestProduct: bestProduct,
                    growth: growth,
                    peakHour: peakHour,
                  ),

                  const SizedBox(height: 24),

                  // ALERTES STOCK
                  _SectionTitle('Alertes stock', p),

                  const SizedBox(height: 12),

                  _StockAlertsCard(
                    products: alertProducts,
                  ),

                  const SizedBox(height: 24),

                  // ACTIVITE RECENTE
                  _SectionTitle('Activité récente', p),

                  const SizedBox(height: 12),

                  _RecentActivity(
                    sales: allSales,
                    alertProducts: alertProducts,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADER
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String name;
  final int alertCount;

  const _Header({
    required this.name,
    required this.alertCount,
  });

  String _formatDate() {
    final now = DateTime.now();

    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return '${days[now.weekday - 1]} ${now.day} '
        '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final headerBackground = p.dark
        ? p.primary.withValues(alpha: 0.18)
        : const Color(0xFFE8F4F1);

    final statusBackground = p.dark
        ? p.accent.withValues(alpha: 0.16)
        : const Color(0xFFFFF0DD);

    final statusText = p.dark
        ? p.accent
        : const Color(0xFFD98228);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        color: headerBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Bonjour, ',
                      style: p.t.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: p.primary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: p.t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.dark
                              ? p.text
                              : const Color(0xFF164D46),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: p.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Votre boutique est sous contrôle',
                        style: p.t.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _formatDate(),
                  style: p.t.labelSmall?.copyWith(
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: p.primary,
                      size: 22,
                    ),
                  ),

                  if (alertCount > 0)
                    Positioned(
                      right: -4,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: headerBackground,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            alertCount > 9 ? '9+' : '$alertCount',
                            style: p.t.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: p.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 9),

              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: p.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// KPI
// -----------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  final double revenue;
  final double margin;
  final int totalUnits;
  final int categoriesCount;
  final double basket;
  final int alertCount;
  final double growth;

  const _KpiGrid({
    required this.revenue,
    required this.margin,
    required this.totalUnits,
    required this.categoriesCount,
    required this.basket,
    required this.alertCount,
    required this.growth,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final growthText = growth >= 0
        ? '+${growth.toStringAsFixed(1)}% vs hier'
        : '${growth.toStringAsFixed(1)}% vs hier';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _KpiCard(
          title: 'Ventes du jour',
          value: _money(revenue),
          color: p.success,
          trend: growthText,
          trendUp: growth >= 0,
        ),
        _KpiCard(
          title: 'Produits en stock',
          value: '$totalUnits',
          color: p.primary,
          trend: '$categoriesCount catégories',
        ),
        _KpiCard(
          title: 'Bénéfice (est.)',
          value: _money(margin),
          color: p.info,
          trend: 'Marge réelle',
        ),
        _KpiCard(
          title: 'Alertes',
          value: '$alertCount',
          color: p.error,
          trend: alertCount > 0
              ? 'Stock faible'
              : 'Stock sous contrôle',
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final String trend;
  final bool trendUp;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.trend,
    this.trendUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: p.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: p.t.bodyMedium?.copyWith(
              color: p.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: p.t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Row(
            children: [
              if (trendUp) ...[
                Icon(
                  Icons.trending_up,
                  size: 14,
                  color: p.success,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  trend,
                  overflow: TextOverflow.ellipsis,
                  style: p.t.bodySmall?.copyWith(
                    color: trendUp ? p.success : p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTIONS RAPIDES
// -----------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onNewSale;
  final VoidCallback onScan;

  const _QuickActions({
    required this.onAddProduct,
    required this.onNewSale,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.add_circle_outline,
            label: 'Ajouter produit',
            onTap: onAddProduct,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionChip(
            icon: Icons.shopping_bag_outlined,
            label: 'Nouvelle vente',
            onTap: onNewSale,
            primary: true,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final bg = primary
        ? p.accent.withValues(alpha: 0.18)
        : p.soft;

    final fg = primary ? p.accent : p.onSoft;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: fg,
                size: 21,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: p.t.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SELECTEUR DE PERIODE
// -----------------------------------------------------------------------------

class _PeriodSelector extends StatelessWidget {
  final _Period value;
  final ValueChanged<_Period> onChanged;

  const _PeriodSelector({
    required this.value,
    required this.onChanged,
  });

  static const Map<_Period, String> _labels = {
    _Period.jour: 'Jour',
    _Period.semaine: 'Semaine',
    _Period.mois: 'Mois',
  };

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: _Period.values.map((period) {
          final selected = period == value;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? p.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _labels[period]!,
                  style: p.t.labelLarge?.copyWith(
                    color: selected ? p.onPrimary : p.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GRAPHIQUE DES VENTES
// -----------------------------------------------------------------------------

class _SalesChartCard extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const _SalesChartCard({
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final maxV = values.isEmpty
        ? 1.0
        : values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Évolution des ventes',
            style: p.t.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final isMax = values[i] == maxV && maxV > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(
                                '${labels.length}-$i-${values[i]}',
                              ),
                              tween: Tween(
                                begin: 0,
                                end: maxV == 0
                                    ? 0
                                    : values[i] / maxV,
                              ),
                              duration: const Duration(
                                milliseconds: 500,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (
                                context,
                                factor,
                                child,
                              ) {
                                final height =
                                    factor.clamp(0.02, 1.0);

                                return FractionallySizedBox(
                                  heightFactor: height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isMax
                                          ? p.primary
                                          : p.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: p.t.labelSmall?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CATEGORIES
// -----------------------------------------------------------------------------

class _CategoriesCard extends StatelessWidget {
  final Map<String, double> quantities;

  const _CategoriesCard({
    required this.quantities,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final entries = quantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = entries.take(3).toList();

    if (topEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: p.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top catégories',
              style: p.t.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune vente pour le moment.',
              style: p.t.bodyMedium?.copyWith(
                color: p.muted,
              ),
            ),
          ],
        ),
      );
    }

    final total = topEntries.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    final data = <(String, double, Color)>[];

    final colors = [
      p.primary,
      p.primary.withValues(alpha: 0.5),
      p.accent,
    ];

    for (var i = 0; i < topEntries.length; i++) {
      final percentage = total == 0
          ? 0.0
          : (topEntries[i].value / total) * 100;

      data.add(
        (
          topEntries[i].key,
          percentage,
          colors[i],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _DonutPainter(
                data
                    .map((item) => (item.$2, item.$3))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top catégories',
                  style: p.t.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final item in data)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: item.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.$1} (${item.$2.round()}%)',
                            overflow: TextOverflow.ellipsis,
                            style: p.t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> slices;

  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;

    final rect = (Offset.zero & size).deflate(stroke / 2);

    final total = slices.fold<double>(
      0,
      (total, slice) => total + slice.$1,
    );

    if (total <= 0) {
      return;
    }

    var start = -math.pi / 2;

    for (final slice in slices) {
      final value = slice.$1;
      final color = slice.$2;

      final sweep = value / total * 2 * math.pi;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        start,
        sweep - 0.04,
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

// -----------------------------------------------------------------------------
// TOP PRODUITS
// -----------------------------------------------------------------------------

class _TopProductsCard extends StatelessWidget {
  final Map<String, double> qty;

  const _TopProductsCard({
    required this.qty,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final entries = qty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(3).toList();

    final maxQ = top.isEmpty ? 1.0 : top.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produits les plus vendus',
            style: p.t.titleMedium,
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            Text(
              'Aucune vente pour le moment.',
              style: p.t.bodyMedium?.copyWith(
                color: p.muted,
              ),
            ),
          for (final entry in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          overflow: TextOverflow.ellipsis,
                          style: p.t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value.round()} vendus',
                        style: p.t.bodySmall?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: maxQ == 0
                          ? 0
                          : entry.value / maxQ,
                      minHeight: 8,
                      backgroundColor: p.soft,
                      color: p.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// INSIGHTS
// -----------------------------------------------------------------------------

class _InsightsRow extends StatelessWidget {
  final String bestProduct;
  final double growth;
  final String peakHour;

  const _InsightsRow({
    required this.bestProduct,
    required this.growth,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final growthText = growth >= 0
        ? '+${growth.toStringAsFixed(1)}%'
        : '${growth.toStringAsFixed(1)}%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                label: 'Meilleur produit',
                value: bestProduct,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightCard(
                label: 'Croissance',
                value: growthText,
                valueColor:
                    growth >= 0 ? p.success : p.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: p.cardDecoration,
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: p.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Heure de pointe des ventes',
                  style: p.t.bodyMedium?.copyWith(
                    color: p.muted,
                  ),
                ),
              ),
              Text(
                peakHour,
                style: p.t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InsightCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: p.t.bodySmall?.copyWith(
              color: p.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? p.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ALERTES STOCK
// -----------------------------------------------------------------------------

class _StockAlertsCard extends StatelessWidget {
  final List<dynamic> products;

  const _StockAlertsCard({
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Container(
      decoration: p.cardDecoration,
      child: Column(
        children: [
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: p.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucune alerte de stock.',
                      style: p.t.bodyMedium?.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0;
              i < products.length && i < 4;
              i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.errorSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: p.error,
                  size: 22,
                ),
              ),
              title: Text(
                products[i].name,
                style: p.t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Il reste ${products[i].quantity} '
                'unité${products[i].quantity > 1 ? 's' : ''}',
                style: p.t.bodySmall?.copyWith(
                  color: p.muted,
                ),
              ),
              trailing: Text(
                'Réapprovisionner',
                style: p.t.labelSmall?.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (i < products.length - 1 && i < 3)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: p.border,
              ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTIVITE RECENTE
// -----------------------------------------------------------------------------

class _RecentActivity extends StatelessWidget {
  final List<Sale> sales;
  final List<dynamic> alertProducts;

  const _RecentActivity({
    required this.sales,
    required this.alertProducts,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final validSales =
        sales
            .where(
              (sale) => sale.status.toUpperCase() != 'CANCELLED',
            )
            .toList()
          ..sort(
            (a, b) => b.dateTime.compareTo(a.dateTime),
          );

    final recentSales = validSales.take(3).toList();

    final children = <Widget>[];

    if (recentSales.isEmpty && alertProducts.isEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: p.cardDecoration,
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: p.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucune activité récente.',
                  style: p.t.bodyMedium?.copyWith(
                    color: p.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final sale in recentSales) {
      final productSummary = sale.items
          .map(
            (item) =>
                '${_formatQuantity(item.qty)}x ${item.name}',
          )
          .join(', ');

      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: p.cardDecoration,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: p.onSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vente : $productSummary',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeDate(sale.dateTime),
                      style: p.t.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${_money(sale.total)}',
                style: p.t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (alertProducts.isNotEmpty) {
      final product = alertProducts.first;

      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: p.cardDecoration,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.errorSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: p.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock bas : ${product.name}',
                      style: p.t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Il reste ${product.quantity} unité'
                      '${product.quantity > 1 ? 's' : ''}',
                      style: p.t.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Alerte',
                style: p.t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: children);
  }

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString();
  }

  static String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'À l’instant';
    }

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    }

    if (difference.inDays == 1) {
      return 'Hier';
    }

    return 'Il y a ${difference.inDays} jours';
  }
}

// -----------------------------------------------------------------------------
// ETAT ERREUR
// -----------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: p.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: p.t.bodyLarge,
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

// -----------------------------------------------------------------------------
// TITRES
// -----------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  final _P p;

  const _SectionTitle(this.text, this.p);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: p.t.titleLarge,
    );
  }
}

// -----------------------------------------------------------------------------
// FORMATAGE
// -----------------------------------------------------------------------------

String _money(num value) {
  final string = value.round().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < string.length; i++) {
    final fromEnd = string.length - i;

    buffer.write(string[i]);

    if (fromEnd > 1 &&
        fromEnd % 3 == 1 &&
        string[i] != '-') {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} F';
}