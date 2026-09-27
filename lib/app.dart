import 'package:flutter/material.dart';

/// Root widget of the application.
///
/// Owns the theme and, once routing is introduced, the router.
/// Business logic and data access must never live here.
class KioskMindApp extends StatelessWidget {
  const KioskMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KioskMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _PlaceholderHome(),
    );
  }
}

/// Temporary home used while no feature is implemented yet.
///
/// Replace it with the first real feature from `lib/features/`.
/// See `docs/ARCHITECTURE.md` for the expected feature layout.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('KioskMind')));
  }
}
