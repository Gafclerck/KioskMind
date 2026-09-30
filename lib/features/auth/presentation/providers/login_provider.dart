import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_gateway.dart';
import 'auth_gateway_provider.dart';

class LoginState {
  const LoginState({
    this.obscurePassword = true,
    this.emailMode = false,
    this.identifier = '',
    this.password = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.success = false,
  });

  final bool obscurePassword;
  final bool emailMode;
  final String identifier;
  final String password;
  final bool isSubmitting;
  final String? errorMessage;
  final String? notice;
  final bool success;

  LoginState copyWith({
    bool? obscurePassword,
    bool? emailMode,
    String? identifier,
    String? password,
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    bool? success,
  }) {
    return LoginState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      emailMode: emailMode ?? this.emailMode,
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
      success: success ?? this.success,
    );
  }
}

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void toggleIdentifierMode() {
    state = state.copyWith(emailMode: !state.emailMode);
  }

  void setIdentifier(String value) {
    state = state.copyWith(identifier: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void clearSubmissionResult() {
    state = state.copyWith(errorMessage: null, notice: null, success: false);
  }

  Future<void> submit() async {
    if (state.isSubmitting) {
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      notice: null,
      success: false,
    );
    if (!state.emailMode) {
      state = state.copyWith(
        isSubmitting: false,
        notice: 'La connexion par téléphone (OTP) arrivera en Phase B',
      );
      return;
    }
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      await gateway.signInWithEmail(
        email: state.identifier,
        password: state.password,
      );
      state = state.copyWith(isSubmitting: false, success: true);
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
    }
  }
}

final loginProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
