import 'dart:async';

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

typedef SendPhoneCodeCall =
    void Function({
      required String phoneNumber,
      required void Function(String verificationId) onCodeSent,
      required void Function(AuthException error) onError,
    });

typedef VerifyPhoneCredentialCall =
    Future<void> Function({
      required String verificationId,
      required String smsCode,
    });

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    this.onSignIn,
    this.onSignUp,
    this.onSendReset,
    this.onSendPhoneCode,
    this.onVerifyPhoneCredential,
  });

  final SignInCall? onSignIn;
  final SignUpCall? onSignUp;
  final SendResetCall? onSendReset;
  final SendPhoneCodeCall? onSendPhoneCode;
  final VerifyPhoneCredentialCall? onVerifyPhoneCredential;

  int signInCalls = 0;
  int signUpCalls = 0;
  int sendResetCalls = 0;
  int sendPhoneCodeCalls = 0;
  int verifyPhoneCredentialCalls = 0;
  String? lastSignInEmail;
  String? lastSignUpEmail;
  String? lastResetEmail;
  String? lastPhoneNumber;
  String? lastVerificationId;
  String? lastSmsCode;

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

  @override
  void sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(AuthException error) onError,
  }) {
    sendPhoneCodeCalls++;
    lastPhoneNumber = phoneNumber;
    final SendPhoneCodeCall? call = onSendPhoneCode;
    if (call != null) {
      call(phoneNumber: phoneNumber, onCodeSent: onCodeSent, onError: onError);
      return;
    }
    scheduleMicrotask(() => onCodeSent('verification-id'));
  }

  @override
  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    verifyPhoneCredentialCalls++;
    lastVerificationId = verificationId;
    lastSmsCode = smsCode;
    final VerifyPhoneCredentialCall? call = onVerifyPhoneCredential;
    if (call != null) {
      return call(verificationId: verificationId, smsCode: smsCode);
    }
    return Future<void>.value();
  }
}
