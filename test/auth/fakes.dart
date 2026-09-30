import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';

typedef SignInCall =
    Future<void> Function({required String email, required String password});

typedef SignUpCall =
    Future<void> Function({
      required String fullName,
      required String phone,
      required String countryCode,
      required String email,
      required String password,
    });

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.onSignIn, this.onSignUp});

  final SignInCall? onSignIn;
  final SignUpCall? onSignUp;

  int signInCalls = 0;
  int signUpCalls = 0;
  String? lastSignInEmail;
  String? lastSignUpEmail;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    signInCalls++;
    lastSignInEmail = email;
    final SignInCall? call = onSignIn;
    if (call != null) {
      return call(email: email, password: password);
    }
    return Future<void>.value();
  }

  @override
  Future<void> signUpWithEmail({
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
    required String password,
  }) {
    signUpCalls++;
    lastSignUpEmail = email;
    final SignUpCall? call = onSignUp;
    if (call != null) {
      return call(
        fullName: fullName,
        phone: phone,
        countryCode: countryCode,
        email: email,
        password: password,
      );
    }
    return Future<void>.value();
  }
}
