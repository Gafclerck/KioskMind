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

typedef SendResetCall = Future<void> Function({required String email});

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.onSignIn, this.onSignUp, this.onSendReset});

  final SignInCall? onSignIn;
  final SignUpCall? onSignUp;
  final SendResetCall? onSendReset;

  int signInCalls = 0;
  int signUpCalls = 0;
  int sendResetCalls = 0;
  String? lastSignInEmail;
  String? lastSignUpEmail;
  String? lastResetEmail;

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

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    sendResetCalls++;
    lastResetEmail = email;
    final SendResetCall? call = onSendReset;
    if (call != null) {
      return call(email: email);
    }
    return Future<void>.value();
  }
}
