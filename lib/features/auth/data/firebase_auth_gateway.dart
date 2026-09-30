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

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  @override
  void sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(AuthException error) onError,
  }) {
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException error) {
        onError(authErrorFrom(error));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Future<void> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      await _storePhoneProfile(
        uid: userCredential.user?.uid,
        phone: userCredential.user?.phoneNumber,
      );
    } catch (error) {
      throw authErrorFrom(error);
    }
  }

  Future<void> _storePhoneProfile({
    required String? uid,
    required String? phone,
  }) async {
    if (uid == null) {
      return;
    }
    try {
      final DocumentReference reference = _firestore
          .collection('users')
          .doc(uid);
      final DocumentSnapshot snapshot = await reference.get();
      if (!snapshot.exists) {
        await reference.set({
          'phone': phone ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException {
      return;
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
