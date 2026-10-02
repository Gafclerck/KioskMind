import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../sales/presentation/pages/sales_dashboard_page.dart';
import '../sales/presentation/pages/sales_history_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SalesDashboardPage(),

    const _PlaceholderPage(
      title: 'Stock',
      icon: Icons.inventory_2_rounded,
    ),

    const SalesHistoryPage(),

    const _PlaceholderPage(
      title: 'Profil',
      icon: Icons.person_rounded,
    ),
  ];

  void _onNavigationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onVoicePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assistant vocal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: _KioskMindBottomNavigation(
        currentIndex: _currentIndex,
        onItemSelected: _onNavigationSelected,
      ),

      floatingActionButton: _VoiceButton(
        onPressed: _onVoicePressed,
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }
}

// ============================================================
// BOTTOM NAVIGATION
// ============================================================

class _KioskMindBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const _KioskMindBottomNavigation({
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // ACCUEIL
            Expanded(
              child: _NavigationItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Accueil',
                selected: currentIndex == 0,
                onTap: () => onItemSelected(0),
              ),
            ),

            // STOCK
            Expanded(
              child: _NavigationItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: 'Stock',
                selected: currentIndex == 1,
                onTap: () => onItemSelected(1),
              ),
            ),

            // ESPACE POUR LE BOUTON VOCAL
            const SizedBox(width: 62),

            // VENTES
            Expanded(
              child: _NavigationItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Ventes',
                selected: currentIndex == 2,
                onTap: () => onItemSelected(2),
              ),
            ),

            // PROFIL
            Expanded(
              child: _NavigationItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person_rounded,
                label: 'Profil',
                selected: currentIndex == 3,
                onTap: () => onItemSelected(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ITEM NAVIGATION
// ============================================================

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor =
        Theme.of(context).colorScheme.onSurfaceVariant;

    final color = selected
        ? AppColors.primary
        : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(
                  selected ? 5 : 2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),

              const SizedBox(height: 3),

              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(
                      color: color,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOUTON VOCAL
// ============================================================

class _VoiceButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _VoiceButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER TEMPORAIRE
// ============================================================

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.primary,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}