import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_gateway.dart';
import 'auth_gateway_provider.dart';

class SignupState {
  const SignupState({
    this.obscurePassword = true,
    this.obscureConfirmation = true,
    this.countryCode = '+225',
    this.password = '',
    this.acceptedTerms = false,
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.success = false,
  });

  final bool obscurePassword;
  final bool obscureConfirmation;
  final String countryCode;
  final String password;
  final bool acceptedTerms;
  final String fullName;
  final String phone;
  final String email;
  final bool isSubmitting;
  final String? errorMessage;
  final bool success;

  SignupState copyWith({
    bool? obscurePassword,
    bool? obscureConfirmation,
    String? countryCode,
    String? password,
    bool? acceptedTerms,
    String? fullName,
    String? phone,
    String? email,
    bool? isSubmitting,
    String? errorMessage,
    bool? success,
  }) {
    return SignupState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmation: obscureConfirmation ?? this.obscureConfirmation,
      countryCode: countryCode ?? this.countryCode,
      password: password ?? this.password,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      success: success ?? this.success,
    );
  }
}

class SignupNotifier extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void toggleConfirmationVisibility() {
    state = state.copyWith(obscureConfirmation: !state.obscureConfirmation);
  }

  void selectCountryCode(String code) {
    state = state.copyWith(countryCode: code);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void setAcceptedTerms(bool accepted) {
    state = state.copyWith(acceptedTerms: accepted);
  }

  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setPhone(String value) {
    state = state.copyWith(phone: value);
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void clearSubmissionResult() {
    state = state.copyWith(errorMessage: null, success: false);
  }

  Future<void> submit() async {
    if (state.isSubmitting) {
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      success: false,
    );
    final AuthGateway gateway = ref.read(authGatewayProvider);
    try {
      await gateway.signUpWithEmail(
        fullName: state.fullName,
        phone: state.phone,
        countryCode: state.countryCode,
        email: state.email,
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

final signupProvider = NotifierProvider<SignupNotifier, SignupState>(
  SignupNotifier.new,
);
