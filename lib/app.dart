import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_toast.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

class KioskMindApp extends StatelessWidget {
  const KioskMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'KioskMind',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: const OnboardingPage(),
      ),
    );
  }
}
