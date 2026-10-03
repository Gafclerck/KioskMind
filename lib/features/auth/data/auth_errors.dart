import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';

AuthException authErrorFrom(Object error) {
  if (error is FirebaseAuthException) {
    return AuthException(messageForFirebaseAuthCode(error.code));
  }
  return const AuthException("Une erreur est survenue, réessayez");
}

String messageForFirebaseAuthCode(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Cette adresse e-mail est déjà utilisée';
    case 'invalid-email':
      return 'Adresse e-mail invalide';
    case 'weak-password':
      return 'Mot de passe trop faible';
    case 'user-not-found':
      return 'Aucun compte associé à cette adresse e-mail';
    case 'wrong-password':
      return 'Mot de passe incorrect';
    case 'missing-email':
      return 'Adresse e-mail manquante';
    case 'invalid-credential':
      return 'Identifiants invalides';
    case 'operation-not-allowed':
      return "La connexion par e-mail n'est pas activée";
    case 'network-request-failed':
      return 'Problème de connexion réseau';
    case 'too-many-requests':
      return 'Trop de tentatives, veuillez patienter';
    default:
      return "Une erreur est survenue, réessayez";
  }
}
