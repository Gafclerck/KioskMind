import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class UpdateUserProfile {
  UpdateUserProfile(this.repository);

  final UserProfileRepository repository;

  Future<void> call({required String uid, required UserProfileUpdate update}) {
    return repository.updateProfile(uid: uid, update: update);
  }
}
