import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/app_preferences_provider.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/providers/auth_state_provider.dart';
import '../features/navigation/main_navigation_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/splash/presentation/splash_page.dart';
import 'app_routes.dart';

/// Listens to authentication and onboarding state changes to trigger GoRouter refreshes.
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<String?>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<bool>(onboardingSeenProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final AsyncValue<String?> authState = _ref.read(authStateProvider);
    final bool hasSeenOnboarding = _ref.read(onboardingSeenProvider);

    // Keep splash while initial auth state is unknown
    if (authState.isLoading) {
      return state.matchedLocation == AppRoutes.splash
          ? null
          : AppRoutes.splash;
    }

    final bool isLoggedIn = authState.valueOrNull != null;
    final String location = state.matchedLocation;

    // 1. If user hasn't completed onboarding yet, force onboarding
    if (!hasSeenOnboarding) {
      return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }

    // 2. If onboarding was already seen, do not allow staying on onboarding page
    if (location == AppRoutes.onboarding) {
      return isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;
    }

    // 3. Public routes allowed without being authenticated
    const List<String> publicRoutes = [AppRoutes.login, AppRoutes.signup];
    if (!isLoggedIn) {
      return publicRoutes.contains(location) ? null : AppRoutes.login;
    }

    // 4. Authenticated users should not stay on splash or login/signup
    if (location == AppRoutes.splash || publicRoutes.contains(location)) {
      return AppRoutes.dashboard;
    }

    // Allow navigation to protected route
    return null;
  }
}

/// Central GoRouter provider for the application.
final appRouterProvider = Provider<GoRouter>((ref) {
  final AppRouterNotifier notifier = AppRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const MainNavigationPage(),
      ),
    ],
  );
});
