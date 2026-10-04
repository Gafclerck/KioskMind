import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../routing/app_routes.dart';
import '../../../navigation/navigation_index_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/logout_provider.dart';
import '../providers/profile_stats_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/profile_avatar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _confirmSignOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'Votre appareil sera déconnecté. Vous pourrez vous reconnecter à tout moment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final bool succeeded = await ref.read(logoutProvider.notifier).signOut();
    if (!mounted) {
      return;
    }
    if (succeeded) {
      AppToast.show(
        ref,
        message: 'Déconnexion réussie',
        type: AppToastType.info,
      );
    } else {
      AppToast.show(
        ref,
        message:
            ref.read(logoutProvider).errorMessage ??
            "Une erreur est survenue, réessayez",
        type: AppToastType.error,
      );
    }
  }

  void _goToSalesHistory() {
    ref.read(navigationIndexProvider.notifier).goTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final ProfileStats stats = ref.watch(profileStatsProvider);
    final bool isSigningOut = ref.watch(logoutProvider).isSigningOut;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Header(
            profile: profile,
            onSettings: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 20),
          _StatsGrid(
            stats: stats,
            profile: profile,
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 24),
          _SectionTitle('Navigation', textTheme),
          const SizedBox(height: 12),
          _NavigationCard(
            scheme: scheme,
            textTheme: textTheme,
            profile: profile,
            onEditProfile: () => context.push(AppRoutes.editProfile),
            onSalesHistory: _goToSalesHistory,
          ),
          const SizedBox(height: 24),
          _SignOutButton(
            isLoading: isSigningOut,
            onPressed: _confirmSignOut,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onSettings});

  final UserProfile? profile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        ProfileAvatar(
          photoUrl: profile?.photoUrl,
          initials: profile?.initials ?? '?',
          radius: 30,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.fullName.isNotEmpty == true
                    ? profile!.fullName
                    : 'Utilisateur',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile?.phone.isNotEmpty == true
                    ? '${profile!.countryCode} ${profile!.phone}'
                    : profile?.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Paramètres',
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.stats,
    required this.profile,
    required this.scheme,
    required this.textTheme,
  });

  final ProfileStats stats;
  final UserProfile? profile;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Membre depuis',
            value: _formatMemberSince(profile?.createdAt),
            scheme: scheme,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Ventes',
            value: '${stats.salesCount}',
            scheme: scheme,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Produits actifs',
            value: '${stats.activeProducts}',
            scheme: scheme,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) {
      return '—';
    }
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.scheme,
    required this.textTheme,
    required this.profile,
    required this.onEditProfile,
    required this.onSalesHistory,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final UserProfile? profile;
  final VoidCallback onEditProfile;
  final VoidCallback onSalesHistory;

  @override
  Widget build(BuildContext context) {
    final String? kioskName = profile?.kioskName;
    final String? market = profile?.marketLocation;
    final String kioskSummary = [
      if (kioskName != null && kioskName.isNotEmpty) kioskName,
      if (market != null && market.isNotEmpty) market,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _NavTile(
            icon: Icons.storefront_outlined,
            title: 'Mon kiosque',
            subtitle: kioskSummary.isNotEmpty
                ? kioskSummary
                : 'À compléter dans « Modifier le profil »',
            onTap: onEditProfile,
            scheme: scheme,
            textTheme: textTheme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),
          _NavTile(
            icon: Icons.receipt_long_outlined,
            title: 'Historique des ventes',
            onTap: onSalesHistory,
            scheme: scheme,
            textTheme: textTheme,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),
          _NavTile(
            icon: Icons.edit_outlined,
            title: 'Modifier le profil',
            onTap: onEditProfile,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.scheme,
    required this.textTheme,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
      ),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({
    required this.isLoading,
    required this.onPressed,
    required this.scheme,
    required this.textTheme,
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Icon(Icons.logout_rounded, color: scheme.error, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                'Se déconnecter',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.textTheme);

  final String text;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: textTheme.titleLarge);
  }
}
