import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

/// Application entry point.
///
/// Keep this thin: it only wires dependencies and bootstraps services.
/// Dependency injection, Riverpod and localization will be added here once the
/// corresponding packages are actually needed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KioskMindApp());
}
