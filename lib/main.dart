import 'package:flutter/material.dart';

import 'app.dart';

/// Application entry point.
///
/// Keep this thin: it only wires dependencies and bootstraps services.
/// Firebase init, dependency injection, Riverpod and localization will be
/// added here once the corresponding packages are actually needed.
void main() {
  runApp(const KioskMindApp());
}
