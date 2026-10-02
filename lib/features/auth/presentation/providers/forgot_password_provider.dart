import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_gateway.dart';
import 'auth_gateway_provider.dart';

class ForgotPasswordState {
  const ForgotPasswordState({
    this.email = '',
    this.isSubmitting = false,
    this.succeeded = false,
    this.errorMessage,
  });

  final String email;
  final bool isSubmitting;
  final bool succeeded;
  final String? errorMessage;

  ForgotPasswordState copyWith({
    String? email,
    bool? isSubmitting,
    bool? succeeded,
    String? errorMessage,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      succeeded: succeeded ?? this.succeeded,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ForgotPasswordNotifier extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void reset() {
    state = const ForgotPasswordState();
  }

  Future<ForgotPasswordState> send() async {
    if (state.isSubmitting) {
      return state;
    }
    state = state.copyWith(
      isSubmitting: true,
      succeeded: false,
      errorMessage: null,
    );
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      await gateway.sendPasswordResetEmail(email: state.email.trim());
      state = state.copyWith(isSubmitting: false, succeeded: true);
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
    }
    return state;
  }
}

final forgotPasswordProvider =
    NotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>(
      ForgotPasswordNotifier.new,
    );
