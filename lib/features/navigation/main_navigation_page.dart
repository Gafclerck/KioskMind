import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../products_stock/presentation/pages/product_list_page.dart';
import '../profile/presentation/pages/profile_page.dart';
import '../sales/presentation/pages/sales_dashboard_page.dart';
import '../sales/presentation/pages/sales_history_page.dart';
import '../voice_assistant/presentation/widgets/voice_session_sheet.dart';
import 'navigation_index_provider.dart';

class MainNavigationPage extends ConsumerWidget {
  const MainNavigationPage({super.key});

  static const List<Widget> _pages = [
    SalesDashboardPage(),
    ProductListPage(),
    SalesHistoryPage(),
    ProfilePage(),
  ];

  void _onNavigationSelected(int index, WidgetRef ref) {
    ref.read(navigationIndexProvider.notifier).goTo(index);
  }

  void _onVoicePressed(BuildContext context) {
    openVoiceSession(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(navigationIndexProvider);
    final Set<int> activatedIndices = ref.watch(navigationActivatedProvider);

    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: currentIndex,
        children: List<Widget>.generate(_pages.length, (int index) {
          if (activatedIndices.contains(index)) {
            return _pages[index];
          }
          return const SizedBox.shrink();
        }),
      ),

      bottomNavigationBar: _KioskMindBottomNavigation(
        currentIndex: currentIndex,
        onItemSelected: (int index) => _onNavigationSelected(index, ref),
      ),

      floatingActionButton: _VoiceButton(
        onPressed: () => _onVoicePressed(context),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

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
            Expanded(
              child: _NavigationItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Accueil',
                selected: currentIndex == 0,
                onTap: () => onItemSelected(0),
              ),
            ),

            Expanded(
              child: _NavigationItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: 'Stock',
                selected: currentIndex == 1,
                onTap: () => onItemSelected(1),
              ),
            ),

            // Emplacement réservé au bouton vocal flottant.
            const SizedBox(width: 62),

            Expanded(
              child: _NavigationItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Ventes',
                selected: currentIndex == 2,
                onTap: () => onItemSelected(2),
              ),
            ),

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
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final color = selected ? AppColors.primary : inactiveColor;

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
                padding: EdgeInsets.all(selected ? 5 : 2),
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
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _VoiceButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _VoiceButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final String label = AppLocalizations.of(context).voicePanelLabel;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
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
                child: Icon(Icons.mic_rounded, color: Colors.white, size: 27),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
