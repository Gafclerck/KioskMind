import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiosk_mind/features/auth/data/auth_errors.dart';
import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';

void main() {
  group('messageForFirebaseAuthCode', () {
    test('maps known codes to French messages', () {
      expect(
        messageForFirebaseAuthCode('email-already-in-use'),
        'Cette adresse e-mail est déjà utilisée',
      );
      expect(
        messageForFirebaseAuthCode('invalid-email'),
        'Adresse e-mail invalide',
      );
      expect(
        messageForFirebaseAuthCode('weak-password'),
        'Mot de passe trop faible',
      );
      expect(
        messageForFirebaseAuthCode('user-not-found'),
        'Aucun compte associé à cette adresse e-mail',
      );
      expect(
        messageForFirebaseAuthCode('wrong-password'),
        'Mot de passe incorrect',
      );
      expect(
        messageForFirebaseAuthCode('missing-email'),
        'Adresse e-mail manquante',
      );
      expect(
        messageForFirebaseAuthCode('invalid-credential'),
        'Identifiants invalides',
      );
      expect(
        messageForFirebaseAuthCode('operation-not-allowed'),
        "La connexion par e-mail n'est pas activée",
      );
      expect(
        messageForFirebaseAuthCode('network-request-failed'),
        'Problème de connexion réseau',
      );
      expect(
        messageForFirebaseAuthCode('invalid-phone-number'),
        'Numéro de téléphone invalide',
      );
      expect(
        messageForFirebaseAuthCode('missing-phone-number'),
        'Numéro de téléphone manquant',
      );
      expect(
        messageForFirebaseAuthCode('invalid-verification-code'),
        'Code de vérification invalide',
      );
      expect(
        messageForFirebaseAuthCode('invalid-verification-id'),
        'Code de vérification expiré, renvoyez un nouveau code',
      );
      expect(
        messageForFirebaseAuthCode('quota-exceeded'),
        'Trop de SMS envoyés, réessayez plus tard',
      );
      expect(
        messageForFirebaseAuthCode('too-many-requests'),
        'Trop de tentatives, veuillez patienter',
      );
      expect(
        messageForFirebaseAuthCode('app-not-authorized'),
        'Application non autorisée pour ce numéro',
      );
    });

    test('falls back to a generic message for unknown codes', () {
      expect(
        messageForFirebaseAuthCode('unknown-code'),
        "Une erreur est survenue, réessayez",
      );
    });
  });

  group('authErrorFrom', () {
    test('wraps a FirebaseAuthException with its French message', () {
      final AuthException error = authErrorFrom(
        FirebaseAuthException(code: 'email-already-in-use'),
      );
      expect(error.message, 'Cette adresse e-mail est déjà utilisée');
    });

    test('falls back to a generic message for unknown errors', () {
      final AuthException error = authErrorFrom(Exception('boom'));
      expect(error.message, "Une erreur est survenue, réessayez");
    });
  });
}
