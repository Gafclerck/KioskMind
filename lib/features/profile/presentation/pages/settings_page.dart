import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/app_preferences_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../routing/app_routes.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/widgets/change_password_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final bool changed = await showChangePasswordDialog(context, ref);
    if (!changed) {
      return;
    }
    AppToast.show(
      ref,
      message: 'Mot de passe modifié',
      type: AppToastType.success,
    );
  }

  void _setThemeMode(WidgetRef ref, ThemeMode mode) {
    ref.read(themeModeProvider.notifier).state = mode;
    final String stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    ref.read(appPreferencesProvider).setThemeMode(stored);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool promosEnabled = ref.watch(promosNotificationsProvider);
    final bool stockAlertsEnabled = ref.watch(stockAlertsProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _SectionTitle('Compte'),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Changer le mot de passe',
              onTap: () => _changePassword(context, ref),
              scheme: scheme,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Préférences'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(Icons.dark_mode_outlined, color: scheme.primary),
              title: const Text('Mode sombre'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: themeMode,
                  onChanged: (ThemeMode? mode) {
                    if (mode != null) {
                      _setThemeMode(ref, mode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Système'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Clair'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Sombre'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Text(
                'Les notifications natives seront activées dans une prochaine '
                'version. Vos préférences sont déjà sauvegardées.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: Icon(Icons.campaign_outlined, color: scheme.primary),
              title: const Text('Offres et promotions'),
              subtitle: const Text('Nouveautés, promos et bons plans'),
              value: promosEnabled,
              onChanged: (bool enabled) {
                ref.read(promosNotificationsProvider.notifier).state = enabled;
                ref
                    .read(appPreferencesProvider)
                    .setPromosNotificationsEnabled(enabled);
                AppToast.show(
                  ref,
                  message:
                      'Préférence enregistrée — Les notifications natives '
                      'arrivent bientôt.',
                  type: AppToastType.info,
                );
              },
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: Icon(
                Icons.inventory_2_outlined,
                color: scheme.primary,
              ),
              title: const Text('Alertes de stock'),
              subtitle: const Text('Produits proches de leur seuil'),
              value: stockAlertsEnabled,
              onChanged: (bool enabled) {
                ref.read(stockAlertsProvider.notifier).state = enabled;
                ref.read(appPreferencesProvider).setStockAlertsEnabled(enabled);
                final String? uid = ref.read(authStateProvider).valueOrNull;
                if (uid != null) {
                  synchroniserAlerteStock(uid, enabled);
                }
                AppToast.show(
                  ref,
                  message: enabled
                      ? 'Alertes de stock activées'
                      : 'Alertes de stock désactivées — vous ne recevrez plus '
                            'de notification, les alertes restent visibles dans '
                            'l\'écran Alertes.',
                  type: AppToastType.info,
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Langue'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(Icons.language_outlined, color: scheme.primary),
              title: const Text('Langue'),
              trailing: const Text('Français'),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Données'),
            _SettingsTile(
              icon: Icons.download_outlined,
              title: 'Exporter mes ventes',
              subtitle: 'CSV ou PDF',
              onTap: () => context.push(AppRoutes.export),
              scheme: scheme,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('À propos'),
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Aide',
              onTap: () => context.push(AppRoutes.settingsHelp),
              scheme: scheme,
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: "Conditions d'Utilisation",
              onTap: () => context.push(AppRoutes.settingsTerms),
              scheme: scheme,
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Politique de Confidentialité',
              onTap: () => context.push(AppRoutes.settingsPrivacy),
              scheme: scheme,
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Version',
              trailingText: '1.0.0',
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailingText == null
          ? (onTap == null
                ? null
                : Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ))
          : Text(trailingText!),
      onTap: onTap,
    );
  }
}
