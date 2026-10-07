import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_remote_data_source.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({required this.dataSource});

  final UserProfileRemoteDataSource dataSource;

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return dataSource.watchProfile(uid: uid);
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  }) {
    return dataSource.updateProfile(uid: uid, update: update);
  }
}
