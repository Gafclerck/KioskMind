import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatting/french_date.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../routing/app_routes.dart';
import '../../../navigation/navigation_index_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/logout_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/profile_avatar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;
    final bool isSigningOut = ref.watch(logoutProvider).isSigningOut;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Header(profile: profile),
          const SizedBox(height: 20),
          _MemberSinceCard(
            createdAt: profile?.createdAt,
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 24),
          _NavigationCard(
            scheme: scheme,
            textTheme: textTheme,
            profile: profile,
            onEditProfile: () => context.push(AppRoutes.editProfile),
            onSalesHistory: () =>
                ref.read(navigationIndexProvider.notifier).goTo(2),
            onSettings: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 24),
          _SignOutButton(
            isLoading: isSigningOut,
            onPressed: () => _confirmSignOut(context, ref),
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

/// En-tête sur une seule ligne : le nom de l'application à gauche, l'avatar
/// de l'utilisateur à droite. Les informations personnelles restent dans
/// « Mon kiosque et moi ».
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'KioskMind',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        ProfileAvatar(
          photoUrl: profile?.photoUrl,
          initials: profile?.initials ?? '?',
          radius: 22,
        ),
      ],
    );
  }
}

class _MemberSinceCard extends StatelessWidget {
  const _MemberSinceCard({
    required this.createdAt,
    required this.scheme,
    required this.textTheme,
  });

  final DateTime? createdAt;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, color: scheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membre depuis',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatFrenchDate(createdAt),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
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

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.scheme,
    required this.textTheme,
    required this.profile,
    required this.onEditProfile,
    required this.onSalesHistory,
    required this.onSettings,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final UserProfile? profile;
  final VoidCallback onEditProfile;
  final VoidCallback onSalesHistory;
  final VoidCallback onSettings;

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
            title: 'Mon kiosque et moi',
            subtitle: kioskSummary.isNotEmpty
                ? kioskSummary
                : 'Complétez vos informations',
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
            icon: Icons.settings_outlined,
            title: 'Paramètres',
            onTap: onSettings,
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

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Votre appareil sera déconnecté. Vous pourrez vous reconnecter à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Se déconnecter'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final bool succeeded = await ref.read(logoutProvider.notifier).signOut();
  if (!context.mounted) {
    return;
  }
  AppToast.show(
    ref,
    message: succeeded
        ? 'Déconnexion réussie'
        : ref.read(logoutProvider).errorMessage ??
              "Une erreur est survenue, réessayez",
    type: succeeded ? AppToastType.info : AppToastType.error,
  );
}
