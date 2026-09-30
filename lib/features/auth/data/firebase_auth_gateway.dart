import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_gateway.dart';
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
