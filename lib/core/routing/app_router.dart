import 'package:go_router/go_router.dart';

import '../../features/navigation/main_navigation_page.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        return const MainNavigationPage();
      },
    ),
  ],
);