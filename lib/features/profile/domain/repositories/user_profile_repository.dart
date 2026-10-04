import '../entities/user_profile.dart';

abstract class UserProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);

  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  });
}
