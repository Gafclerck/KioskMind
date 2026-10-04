import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';
import '../models/user_profile_model.dart';

abstract class UserProfileRemoteDataSource {
  Stream<UserProfile?> watchProfile({required String uid});

  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  });
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  UserProfileRemoteDataSourceImpl({required this.firestore});

  final FirebaseFirestore firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      firestore.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile({required String uid}) {
    return _doc(uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
          UserProfileModel.fromMap(snapshot.data()),
    );
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  }) {
    return _doc(
      uid,
    ).set(UserProfileModel.toUpdateMap(update), SetOptions(merge: true));
  }
}
