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

typedef ChangePasswordCall =
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    });

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    this.onSignIn,
    this.onSignUp,
    this.onSendReset,
    this.onChangePassword,
  });

  final SignInCall? onSignIn;
  final SignUpCall? onSignUp;
  final SendResetCall? onSendReset;
  final ChangePasswordCall? onChangePassword;

  final Map<String, String> phoneEmails = <String, String>{};

  /// Phones owned by the current user themselves, excluded via [exceptUid].
  final Map<String, String> ownerPhones = <String, String>{};

  int signInCalls = 0;
  int signUpCalls = 0;
  int sendResetCalls = 0;
  int phoneInUseCalls = 0;
  int phoneSearchCalls = 0;
  int signOutCalls = 0;
  int changePasswordCalls = 0;
  String? lastSignInEmail;
  String? lastSignUpEmail;
  String? lastResetEmail;
  String? lastCheckedPhone;
  String? lastCheckedCountryCode;
  String? lastExceptUid;
  String? lastPhoneSearchNumber;
  String? lastCurrentPassword;
  String? lastNewPassword;

  void registerPhone(String fullPhone, String email) {
    phoneEmails[fullPhone] = email;
  }

  void registerOwnerPhone(String fullPhone) {
    ownerPhones[fullPhone] = 'self';
  }

  @override
  Future<bool> isPhoneInUse({
    required String countryCode,
    required String phone,
    String? exceptUid,
  }) async {
    phoneInUseCalls++;
    lastCheckedCountryCode = countryCode;
    lastCheckedPhone = phone;
    lastExceptUid = exceptUid;
    final String key = '$countryCode$phone';
    if (phoneEmails.containsKey(key)) {
      return true;
    }
    return ownerPhones.containsKey(key) &&
        (exceptUid == null || exceptUid != 'self');
  }

  @override
  Future<String?> findEmailByPhone({required String phoneNumber}) async {
    phoneSearchCalls++;
    lastPhoneSearchNumber = phoneNumber;
    return phoneEmails[phoneNumber];
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
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    final ChangePasswordCall? call = onChangePassword;
    if (call != null) {
      return call(currentPassword: currentPassword, newPassword: newPassword);
    }
  }
}
