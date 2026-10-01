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

  final Map<String, String> phoneEmails = <String, String>{};

  int signInCalls = 0;
  int signUpCalls = 0;
  int sendResetCalls = 0;
  int sendPhoneCodeCalls = 0;
  int verifyPhoneCredentialCalls = 0;
  int phoneInUseCalls = 0;
  String? lastSignInEmail;
  String? lastSignUpEmail;
  String? lastResetEmail;
  String? lastPhoneNumber;
  String? lastVerificationId;
  String? lastSmsCode;
  String? lastCheckedPhone;
  String? lastCheckedCountryCode;

  void registerPhone(String fullPhone, String email) {
    phoneEmails[fullPhone] = email;
  }

  @override
  Future<bool> isPhoneInUse({
    required String countryCode,
    required String phone,
  }) async {
    phoneInUseCalls++;
    lastCheckedCountryCode = countryCode;
    lastCheckedPhone = phone;
    return phoneEmails.containsKey('$countryCode$phone');
  }

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
  }) async {
    if (await isPhoneInUse(countryCode: countryCode, phone: phone)) {
      throw phoneAlreadyInUseException;
    }
    signUpCalls++;
    lastSignUpEmail = email;
    registerPhone('$countryCode$phone', email);
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
