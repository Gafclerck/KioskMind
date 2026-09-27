import 'package:flutter/material.dart';

import 'app.dart';

/// Application entry point.
///
/// Keep this thin: it only wires dependencies and bootstraps services.
/// Firebase init, dependency injection and localization will be added here
/// once the corresponding packages are actually needed.
/// See `docs/ARCHITECTURE.md`.
void main() {
  runApp(const KioskMindApp());
}
