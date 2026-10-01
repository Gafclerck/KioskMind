abstract class AuthGateway {
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<bool> isPhoneInUse({
    required String countryCode,
    required String phone,
  });

  Future<String?> findEmailByPhone({required String phoneNumber});

  void sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(AuthException error) onError,
  });

  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  });
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

const AuthException phoneAlreadyInUseException = AuthException(
  'Ce numéro de téléphone est déjà associé à un autre compte.',
);

const AuthException phoneNotFoundException = AuthException(
  'Aucun compte n\'est associé à ce numéro de téléphone. Veuillez vous inscrire.',
);
