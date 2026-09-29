import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginState {
  const LoginState({this.obscurePassword = true, this.emailMode = false});

  final bool obscurePassword;
  final bool emailMode;

  LoginState copyWith({bool? obscurePassword, bool? emailMode}) {
    return LoginState(
      obscurePassword: obscurePassword ?? this.obscurePassword,
      emailMode: emailMode ?? this.emailMode,
    );
  }
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void toggleIdentifierMode() {
    state = state.copyWith(emailMode: !state.emailMode);
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
