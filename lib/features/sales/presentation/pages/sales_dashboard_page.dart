import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_routes.dart';
import '../../domain/entities/daily_stats.dart';

enum _Period { jour, semaine, mois }

// -----------------------------------------------------------------------------
// PALETTE
// -----------------------------------------------------------------------------

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
// PAGE
// -----------------------------------------------------------------------------

class SalesDashboardPage extends ConsumerStatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  ConsumerState<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends ConsumerState<SalesDashboardPage> {
  late Future<DailyStats> _future;

  _Period _period = _Period.semaine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // DONNÉES FICTIVES
  // ---------------------------------------------------------------------------
  // Temporaire uniquement pour visualiser le Dashboard.
  // Firebase sera reconnecté plus tard via GetSalesDashboard.

  void _load() {
    _future = Future.delayed(
      const Duration(milliseconds: 400),
      () => DailyStats(
        revenue: 320500,
        cost: 236500,
        salesCount: 18,
        qtyByProduct: {'Sac de Riz 50kg': 12, 'Huile Dinor': 9, 'Sucre 1kg': 7},
      ),
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  // ---------------------------------------------------------------------------
  // DONNÉES DU GRAPHIQUE
  // ---------------------------------------------------------------------------

  (List<String>, List<double>) get _chart {
    return switch (_period) {
      _Period.jour => (
        ['8h', '10h', '12h', '14h', '16h', '18h', '20h'],
        [20, 45, 80, 35, 60, 95, 40],
      ),
      _Period.semaine => (
        ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
        [45, 60, 85, 38, 100, 92, 50],
      ),
      _Period.mois => (['S1', 'S2', 'S3', 'S4'], [70, 85, 60, 95]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DailyStats>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: p.primary));
            }

            if (snap.hasError || !snap.hasData) {
              return _ErrorState(
                message: 'Impossible de charger les statistiques.',
                onRetry: _refresh,
              );
            }

            final s = snap.data!;

            final revenue = s.revenue.toDouble();

            final margin = revenue - s.cost.toDouble();

            final basket = s.salesCount > 0 ? revenue / s.salesCount : 0.0;

            final (labels, values) = _chart;

            return RefreshIndicator(
              onRefresh: _refresh,
              color: p.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const _Header(name: 'Amadou', alertCount: 4),

                  const SizedBox(height: 20),

                  _KpiGrid(
                    revenue: revenue,
                    margin: margin,
                    salesCount: s.salesCount,
                    basket: basket,
                  ),

                  const SizedBox(height: 24),

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
                    onScan: () => _toast('Scanner bientôt disponible'),
                  ),

                  const SizedBox(height: 24),

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

                  _SalesChartCard(labels: labels, values: values),

                  const SizedBox(height: 12),

                  const _CategoriesCard(),

                  const SizedBox(height: 12),

                  _TopProductsCard(qty: s.qtyByProduct),

                  const SizedBox(height: 12),

                  const _InsightsRow(),

                  const SizedBox(height: 24),

                  _SectionTitle('Alertes stock', p),

                  const SizedBox(height: 12),

                  const _StockAlertsCard(),

                  const SizedBox(height: 24),

                  _SectionTitle('Activité récente', p),

                  const SizedBox(height: 12),

                  const _RecentActivity(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// -----------------------------------------------------------------------------
// HEADER
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String name;
  final int alertCount;

  const _Header({required this.name, required this.alertCount});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $name 👋',
                style: p.t.headlineMedium?.copyWith(color: p.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Votre boutique est sous contrôle',
                style: p.t.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),

        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.card,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
              child: IconButton(
                onPressed: () {
                  context.push(AppRoutes.notificationsAlert);
                },
                icon: Icon(Icons.notifications_none_rounded, color: p.text),
              ),
            ),

            if (alertCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.card, width: 1.5),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: 10),

        CircleAvatar(
          radius: 22,
          backgroundColor: p.soft,
          child: Icon(Icons.person_rounded, color: p.onSoft),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// KPI
// -----------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  final double revenue;
  final double margin;
  final int salesCount;
  final double basket;

  const _KpiGrid({
    required this.revenue,
    required this.margin,
    required this.salesCount,
    required this.basket,
  });

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

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
          trend: '+12% vs hier',
          trendUp: true,
        ),

        _KpiCard(
          title: 'Bénéfice (est.)',
          value: _money(margin),
          color: p.info,
          trend: '+8% vs hier',
          trendUp: true,
        ),

        _KpiCard(
          title: 'Transactions',
          value: '$salesCount',
          color: p.primary,
          trend: 'Panier moyen ${_money(basket)}',
        ),

        _KpiCard(
          title: 'Alertes',
          value: '4',
          color: p.error,
          trend: 'Stock faible',
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
          Text(title, style: p.t.bodySmall?.copyWith(color: p.muted)),

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
                Icon(Icons.trending_up, size: 14, color: p.success),
                const SizedBox(width: 4),
              ],

              Flexible(
                child: Text(
                  trend,
                  overflow: TextOverflow.ellipsis,
                  style: p.t.labelSmall?.copyWith(
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
            label: 'Ajouter\nproduit',
            onTap: onAddProduct,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _ActionChip(
            icon: Icons.shopping_bag_outlined,
            label: 'Nouvelle\nvente',
            onTap: onNewSale,
            primary: true,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _ActionChip(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scanner',
            onTap: onScan,
          ),
        ),
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

    final bg = primary ? p.primary : p.soft;
    final fg = primary ? p.onPrimary : p.onSoft;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 26),

              const SizedBox(height: 6),

              Text(
                label,
                textAlign: TextAlign.center,
                style: p.t.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
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

  const _PeriodSelector({required this.value, required this.onChanged});

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
// GRAPHIQUE
// -----------------------------------------------------------------------------

class _SalesChartCard extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const _SalesChartCard({required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution des ventes', style: p.t.titleMedium),

          const SizedBox(height: 16),

          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final isMax = values[i] == maxV;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('${labels.length}-$i'),
                              tween: Tween(
                                begin: 0,
                                end: maxV == 0 ? 0 : values[i] / maxV,
                              ),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              builder: (context, factor, child) {
                                final height = factor.clamp(0.02, 1.0);

                                return FractionallySizedBox(
                                  heightFactor: height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isMax
                                          ? p.primary
                                          : p.primary.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
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
                          style: p.t.labelSmall?.copyWith(color: p.muted),
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
  const _CategoriesCard();

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    final data = [
      ('Alimentation', 50.0, p.primary),
      ('Boissons', 42.0, p.primary.withValues(alpha: 0.5)),
      ('Autres', 8.0, p.accent),
    ];

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
                data.map((item) => (item.$2, item.$3)).toList(),
              ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top catégories', style: p.t.titleMedium),

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

                        Text(
                          '${item.$1} (${item.$2.round()}%)',
                          style: p.t.bodySmall,
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

    final total = slices.fold<double>(0, (total, slice) => total + slice.$1);

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

      canvas.drawArc(rect, start, sweep - 0.04, false, paint);

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

  const _TopProductsCard({required this.qty});

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
          Text('Produits les plus vendus', style: p.t.titleMedium),

          const SizedBox(height: 14),

          if (top.isEmpty)
            Text(
              'Aucune vente pour le moment.',
              style: p.t.bodyMedium?.copyWith(color: p.muted),
            ),

          for (final entry in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        style: p.t.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: maxQ == 0 ? 0 : entry.value / maxQ,
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
  const _InsightsRow();

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: _InsightCard(
                label: 'Meilleur produit',
                value: 'Sac de Riz 50kg',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _InsightCard(
                label: 'Croissance',
                value: '+18,4%',
                valueColor: p.success,
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
              Icon(Icons.schedule_rounded, color: p.primary, size: 20),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Heure de pointe des ventes',
                  style: p.t.bodyMedium?.copyWith(color: p.muted),
                ),
              ),

              Text(
                '17h00 - 19h00',
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
          Text(label, style: p.t.bodySmall?.copyWith(color: p.muted)),

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
  const _StockAlertsCard();

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    const items = [
      ('Huile Dinor', 3),
      ('Sucre 1kg', 5),
      ('Lait en poudre', 2),
      ('Savon Citron', 4),
    ];

    return Container(
      decoration: p.cardDecoration,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
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
                items[i].$1,
                style: p.t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Il reste ${items[i].$2} unités',
                style: p.t.bodySmall?.copyWith(color: p.muted),
              ),
              trailing: Text(
                'Réapprovisionner',
                style: p.t.labelSmall?.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (i < items.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTIVITÉ RÉCENTE
// -----------------------------------------------------------------------------

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    const items = [
      (
        'Vente : 2x Sac de Riz 50kg',
        'Il y a 5 min · Par Amadou',
        '+34 000 F',
        false,
      ),
      (
        'Stock bas : Huile Dinor',
        'Il y a 20 min · Seuil : 3 restants',
        'Alerte',
        true,
      ),
      (
        'Vente : 5x Canettes Coca-Cola',
        'Il y a 1 h · Par Fatou',
        '+2 500 F',
        false,
      ),
    ];

    return Column(
      children: [
        for (final item in items)
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
                    color: item.$4 ? p.errorSoft : p.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.$4
                        ? Icons.warning_amber_rounded
                        : Icons.shopping_cart_outlined,
                    color: item.$4 ? p.error : p.onSoft,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: p.t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        item.$2,
                        style: p.t.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  item.$3,
                  style: p.t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.$4 ? p.error : p.success,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ETAT D'ERREUR
// -----------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = _P.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: p.error),

            const SizedBox(height: 12),

            Text(message, textAlign: TextAlign.center, style: p.t.bodyLarge),

            const SizedBox(height: 16),

            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TITRE DE SECTION
// -----------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  final _P p;

  const _SectionTitle(this.text, this.p);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: p.t.titleLarge);
  }
}

// -----------------------------------------------------------------------------
// FORMAT MONÉTAIRE
// -----------------------------------------------------------------------------
//
// Exemple :
// 320500 -> 320 500 F
// 1250000 -> 1 250 000 F

String _money(num value) {
  final string = value.round().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < string.length; i++) {
    final fromEnd = string.length - i;

    buffer.write(string[i]);

    if (fromEnd > 1 && fromEnd % 3 == 1 && string[i] != '-') {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} F';
}
