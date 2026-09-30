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
    this.otpRequested = false,
    this.otpVerificationId,
    this.successMessage,
    this.success = false,
  });

  final bool obscurePassword;
  final bool emailMode;
  final String identifier;
  final String password;
  final bool isSubmitting;
  final String? errorMessage;
  final bool otpRequested;
  final String? otpVerificationId;
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
    bool? otpRequested,
    Object? otpVerificationId = _unset,
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
      otpRequested: otpRequested ?? this.otpRequested,
      otpVerificationId: identical(otpVerificationId, _unset)
          ? this.otpVerificationId
          : otpVerificationId as String?,
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

  void cancelOtp() {
    state = state.copyWith(
      otpRequested: false,
      otpVerificationId: null,
      errorMessage: null,
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
    if (!state.emailMode) {
      await _requestPhoneCode();
      return;
    }
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      await gateway.signInWithEmail(
        email: state.identifier,
        password: state.password,
      );
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

  Future<bool> resendPhoneOtp() async {
    if (state.isSubmitting) {
      return false;
    }
    return _requestPhoneCode();
  }

  Future<bool> verifyPhoneOtp(String smsCode) async {
    final String? verificationId = state.otpVerificationId;
    if (verificationId == null || state.isSubmitting) {
      return false;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      successMessage: null,
    );
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      await gateway.signInWithPhoneCredential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      state = state.copyWith(
        isSubmitting: false,
        otpRequested: false,
        otpVerificationId: null,
        success: true,
        successMessage: 'Code vérifié, connexion réussie',
      );
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
      return false;
    }
  }

  Future<bool> _requestPhoneCode() async {
    state = state.copyWith(
      errorMessage: null,
      otpRequested: false,
      otpVerificationId: null,
    );
    final AuthGateway gateway = ref.read(authGatewayProvider);
    final String phoneNumber = _normalizePhone(state.identifier);
    try {
      final String verificationId = await _awaitCodeSent(gateway, phoneNumber);
      state = state.copyWith(
        isSubmitting: false,
        otpRequested: true,
        otpVerificationId: verificationId,
        successMessage: null,
      );
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: "Une erreur est survenue, réessayez",
      );
      return false;
    }
  }

  Future<String> _awaitCodeSent(AuthGateway gateway, String phoneNumber) {
    final Completer<String> completer = Completer<String>();
    gateway.sendPhoneVerificationCode(
      phoneNumber: phoneNumber,
      onCodeSent: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      onError: (AuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    return completer.future;
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
