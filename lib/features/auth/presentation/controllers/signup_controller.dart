import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignupState {
  const SignupState({
    this.obscurePassword = true,
    this.obscureConfirmation = true,
    this.countryCode = '+225',
    this.password = '',
    this.acceptedTerms = false,
  });

  final bool obscurePassword;
  final bool obscureConfirmation;
  final String countryCode;
  final String password;
  final bool acceptedTerms;

  SignupState copyWith({
    bool? obscurePassword,
    bool? obscureConfirmation,
    String? countryCode,
    String? password,
    bool? acceptedTerms,
  }) {
    return SignupState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmation: obscureConfirmation ?? this.obscureConfirmation,
      countryCode: countryCode ?? this.countryCode,
      password: password ?? this.password,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    );
  }
}

class SignupController extends Notifier<SignupState> {
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
}

final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(SignupController.new);
