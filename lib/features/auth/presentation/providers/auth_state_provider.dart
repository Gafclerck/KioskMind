import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the current authenticated user's ID, or `null` if unauthenticated.
///
/// When Firebase is not initialized (e.g. in isolated widget tests), this
/// safely emits `null` rather than throwing an exception.
final authStateProvider = StreamProvider<String?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map(
      (User? user) => user?.uid,
    );
  } catch (_) {
    return Stream<String?>.value(null);
  }
});
