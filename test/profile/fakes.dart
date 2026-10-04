import 'package:kiosk_mind/features/profile/domain/entities/user_profile.dart';
import 'package:kiosk_mind/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:kiosk_mind/features/profile/domain/services/avatar_upload_service.dart';

class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({UserProfile? initialProfile})
    : profile = initialProfile;

  UserProfile? profile;
  final List<(String, UserProfileUpdate)> updates =
      <(String, UserProfileUpdate)>[];

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      Stream<UserProfile?>.value(profile);

  @override
  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  }) async {
    updates.add((uid, update));
    final UserProfile? current = profile;
    profile = UserProfile(
      fullName: update.fullName,
      phone: update.phone,
      countryCode: update.countryCode,
      email: current?.email ?? '',
      createdAt: current?.createdAt,
      kioskName: update.kioskName,
      marketLocation: update.marketLocation,
      businessType: update.businessType,
      photoUrl: update.photoUrl,
    );
  }
}

class FakeAvatarUploadService implements AvatarUploadService {
  FakeAvatarUploadService({this.urlToReturn, this.shouldThrow = false});

  String? urlToReturn;
  bool shouldThrow;
  int calls = 0;
  String? lastUid;

  @override
  Future<String?> pickAndUpload({required String uid}) async {
    calls++;
    lastUid = uid;
    if (shouldThrow) {
      throw Exception('upload failed');
    }
    return urlToReturn;
  }
}
