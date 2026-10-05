import '../../../../../core/usecase/result.dart';
import '../../../domain/entities/intent_input.dart';
import '../../../domain/entities/intent_result.dart';
import '../../../domain/ports/command_context.dart';
import '../../../domain/ports/intent_handler.dart';

typedef PageNavigator = void Function(int tabIndex, String destination);

/// Real handler for screen navigation requests.
final class RealNavigateHandler implements NavigateToPageHandler {
  RealNavigateHandler({required this.navigator});

  final PageNavigator navigator;

  @override
  String get intentId => 'navigate_to_page';

  @override
  Future<Result<NavigateToPageResult>> execute(
    CommandContext context,
    NavigateToPageInput input,
  ) async {
    final String dest = input.destination.toLowerCase();
    final (int tabIndex, String label) = _resolveDestination(dest);

    navigator(tabIndex, dest);

    return Success<NavigateToPageResult>((destination: dest, label: label));
  }

  (int, String) _resolveDestination(String dest) {
    if (dest.contains('stock') ||
        dest.contains('produit') ||
        dest.contains('inventaire')) {
      return (1, 'Mon Stock');
    }
    if (dest.contains('historique') || dest.contains('journal')) {
      return (2, 'Historique des Ventes');
    }
    if (dest.contains('profil') ||
        dest.contains('parametre') ||
        dest.contains('compte')) {
      return (3, 'Mon Profil');
    }
    return (0, 'Accueil');
  }
}
