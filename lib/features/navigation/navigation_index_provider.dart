import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet courant de la navigation principale (0 = Accueil, 2 = Ventes,
/// 3 = Profil). Permet à n'importe quel écran de basculer vers un onglet
/// existant, sans dupliquer de page (principe d'adresse unique).
class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void goTo(int index) {
    state = index;
    ref.read(navigationActivatedProvider.notifier).state = {
      ...ref.read(navigationActivatedProvider),
      index,
    };
  }
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);

/// Onglets déjà construits (construction paresseuse de l'IndexedStack).
final navigationActivatedProvider = StateProvider<Set<int>>((ref) => {0});
