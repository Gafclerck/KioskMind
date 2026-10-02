import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _PlaceholderPage(
      title: 'Accueil',
      icon: Icons.home_outlined,
    ),
    _PlaceholderPage(
      title: 'Stock',
      icon: Icons.inventory_2_outlined,
    ),
    _PlaceholderPage(
      title: 'Ventes',
      icon: Icons.receipt_long_outlined,
    ),
    _PlaceholderPage(
      title: 'Profil',
      icon: Icons.person_outline,
    ),
  ];

  void _onNavigationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onVoicePressed() {
    // La logique vocale sera ajoutée par l'équipe Voice.
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
      bottomNavigationBar: const _KioskMindBottomNavigation(),
      floatingActionButton: _VoiceButton(
        onPressed: _onVoicePressed,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _KioskMindBottomNavigation extends StatelessWidget {
  const _KioskMindBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<
        _MainNavigationPageState>();

    final currentIndex = state?._currentIndex ?? 0;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavigationItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Accueil',
                selected: currentIndex == 0,
                onTap: () => state?._onNavigationSelected(0),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
                label: 'Stock',
                selected: currentIndex == 1,
                onTap: () => state?._onNavigationSelected(1),
              ),
            ),

            // Espace réservé au bouton vocal central.
            const SizedBox(width: 58),

            Expanded(
              child: _NavigationItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Ventes',
                selected: currentIndex == 2,
                onTap: () => state?._onNavigationSelected(2),
              ),
            ),
            Expanded(
              child: _NavigationItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profil',
                selected: currentIndex == 3,
                onTap: () => state?._onNavigationSelected(3),
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
    final color = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 17,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: color,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _VoiceButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
              Icons.mic,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

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

