import 'dart:async';

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
    this.successMessage,
    this.success = false,
  });

  final bool obscurePassword;
  final bool emailMode;
  final String identifier;
  final String password;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final bool success;

  static const Object _unset = Object();

  LoginState copyWith({
    bool? obscurePassword,
    bool? emailMode,
    String? identifier,
    String? password,
    bool? isSubmitting,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
    bool? success,
  }) {
    return LoginState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      emailMode: emailMode ?? this.emailMode,
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _unset)
          ? this.successMessage
          : successMessage as String?,
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

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearSubmissionResult() {
    state = state.copyWith(
      errorMessage: null,
      successMessage: null,
      success: false,
    );
  }

  Future<void> submit() async {
    if (state.isSubmitting) {
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      successMessage: null,
      success: false,
    );
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      final String email = state.emailMode
          ? state.identifier
          : await _resolveEmail(gateway);
      await gateway.signInWithEmail(email: email, password: state.password);
      state = state.copyWith(
        isSubmitting: false,
        success: true,
        successMessage: 'Connexion réussie',
      );
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
    }
  }

  Future<String> _resolveEmail(AuthGateway gateway) async {
    final String normalized = _normalizePhone(state.identifier);
    final String? email = await gateway.findEmailByPhone(
      phoneNumber: normalized,
    );
    if (email == null) {
      throw phoneNotFoundException;
    }
    return email;
  }

  String _normalizePhone(String value) {
    final String sanitized = value.replaceAll(RegExp(r'[\s\-().]'), '');
    if (sanitized.startsWith('+')) {
      return sanitized;
    }
    return '+225$sanitized';
  }
}

final loginProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
