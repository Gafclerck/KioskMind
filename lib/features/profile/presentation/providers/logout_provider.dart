import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_gateway_provider.dart';

class LogoutState {
  const LogoutState({this.isSigningOut = false, this.errorMessage});

  final bool isSigningOut;
  final String? errorMessage;

  LogoutState copyWith({bool? isSigningOut, String? errorMessage}) {
    return LogoutState(
      isSigningOut: isSigningOut ?? this.isSigningOut,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LogoutNotifier extends Notifier<LogoutState> {
  @override
  LogoutState build() => const LogoutState();

  /// Déconnecte l'utilisateur. Le router redirige automatiquement vers /login
  /// quand `authStateProvider` émet `null`. Retourne `true` en cas de succès.
  Future<bool> signOut() async {
    if (state.isSigningOut) {
      return false;
    }
    state = state.copyWith(isSigningOut: true, errorMessage: null);
    try {
      await ref.read(authGatewayProvider).signOut();
      state = const LogoutState();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSigningOut: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
      return false;
    }
  }
}

final logoutProvider = NotifierProvider<LogoutNotifier, LogoutState>(
  LogoutNotifier.new,
);
