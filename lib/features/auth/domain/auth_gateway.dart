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

  /// Checks whether a phone number is already attached to another account.
  ///
  /// [exceptUid] excludes the given user document when it matches, so editing
  /// one's own profile does not report the kept number as already in use.
  Future<bool> isPhoneInUse({
    required String countryCode,
    required String phone,
    String? exceptUid,
  });

  Future<String?> findEmailByPhone({required String phoneNumber});

  Future<void> signOut();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
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
