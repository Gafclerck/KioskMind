import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode d'affichage sélectionné par l'utilisateur.
///
/// Valeur initiale injectée au démarrage (préférence persistée), puis
/// mise à jour depuis l'écran Paramètres.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
