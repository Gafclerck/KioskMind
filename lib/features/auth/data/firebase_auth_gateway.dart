import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';
import '../domain/country_codes.dart';
import 'auth_errors.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
    required String password,
  }) async {
    try {
      if (await isPhoneInUse(countryCode: countryCode, phone: phone)) {
        throw phoneAlreadyInUseException;
      }
    } catch (error) {
      if (error is AuthException) {
        rethrow;
      }
      throw authErrorFrom(error);
    }
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      await _storeProfile(
        uid: credential.user?.uid,
        fullName: fullName,
        phone: phone,
        countryCode: countryCode,
        email: email,
      );
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  @override
  Future<bool> isPhoneInUse({
    required String countryCode,
    required String phone,
    String? exceptUid,
  }) async {
    final QuerySnapshot paired = await _firestore
        .collection('users')
        .where('countryCode', isEqualTo: countryCode)
        .where('phone', isEqualTo: phone)
        .limit(2)
        .get();
    if (_isOwnedByAnother(paired, exceptUid)) {
      return true;
    }
    final QuerySnapshot normalized = await _firestore
        .collection('users')
        .where('phone', isEqualTo: '$countryCode$phone')
        .limit(2)
        .get();
    return _isOwnedByAnother(normalized, exceptUid);
  }

  bool _isOwnedByAnother(QuerySnapshot snapshot, String? exceptUid) {
    for (final QueryDocumentSnapshot<Object?> doc in snapshot.docs) {
      if (doc.id != exceptUid) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<String?> findEmailByPhone({required String phoneNumber}) async {
    final ({String countryCode, String phone})? split = splitPhoneNumber(
      phoneNumber,
    );
    if (split != null) {
      final QuerySnapshot paired = await _firestore
          .collection('users')
          .where('countryCode', isEqualTo: split.countryCode)
          .where('phone', isEqualTo: split.phone)
          .limit(1)
          .get();
      if (paired.docs.isNotEmpty) {
        return _emailFrom(paired.docs.first);
      }
    }
    final QuerySnapshot normalized = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    if (normalized.docs.isNotEmpty) {
      return _emailFrom(normalized.docs.first);
    }
    return null;
  }

  String _emailFrom(QueryDocumentSnapshot<Object?> snapshot) {
    final Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
    final Object? email = data?['email'];
    if (email is String && email.isNotEmpty) {
      return email;
    }
    throw const AuthException('Adresse e-mail invalide');
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Vous devez être connecté');
    }
    final String email = user.email ?? '';
    final AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } catch (error) {
      if (error is FirebaseAuthException &&
          error.code == 'invalid-credential') {
        throw const AuthException('Mot de passe actuel incorrect');
      }
      throw authErrorFrom(error);
    }
    try {
      await user.updatePassword(newPassword);
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  Future<void> _storeProfile({
    required String? uid,
    required String fullName,
    required String phone,
    required String countryCode,
    required String email,
  }) async {
    if (uid == null) {
      return;
    }
    try {
      await _firestore.collection('users').doc(uid).set({
        'fullName': fullName,
        'phone': phone,
        'countryCode': countryCode,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      return;
    }
  }
}
