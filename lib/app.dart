import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_toast.dart';
import 'routing/app_router.dart';

class KioskMindApp extends StatelessWidget {
  const KioskMindApp({super.key, this.overrides});

  final List<Override>? overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides ?? const <Override>[],
      child: const _KioskMindMaterialApp(),
    );
  }
}

class _KioskMindMaterialApp extends ConsumerWidget {
  const _KioskMindMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'KioskMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        return AppToastHost(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
