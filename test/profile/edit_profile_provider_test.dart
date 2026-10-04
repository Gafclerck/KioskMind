import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:kiosk_mind/features/profile/domain/entities/user_profile.dart';
import 'package:kiosk_mind/features/profile/domain/usecases/update_user_profile.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/avatar_upload_service_provider.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/edit_profile_provider.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/user_profile_provider.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

Future<ProviderContainer> makeContainer({
  FakeAuthGateway? gateway,
  FakeUserProfileRepository? repository,
  FakeAvatarUploadService? avatar,
  String authUid = 'uid',
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(authUid)),
      authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
      updateUserProfileProvider.overrideWith(
        (ref) => UpdateUserProfile(repository ?? FakeUserProfileRepository()),
      ),
      avatarUploadServiceProvider.overrideWithValue(
        avatar ?? FakeAvatarUploadService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen<AsyncValue<String?>>(authStateProvider, (_, _) {});
  await container.read(authStateProvider.future);
  return container;
}

UserProfile buildProfile({
  String fullName = 'David Koné',
  String phone = '0700000000',
  String countryCode = '+225',
}) {
  return UserProfile(
    fullName: fullName,
    phone: phone,
    countryCode: countryCode,
    email: 'david@example.com',
    createdAt: DateTime(2026, 1, 15),
    kioskName: 'Kiosque du Sud',
    marketLocation: 'Marché de Treichville',
    businessType: 'Alimentation générale',
  );
}

void main() {
  group('EditProfileState.load', () {
    test('hydrates the form from the current profile', () async {
      final FakeUserProfileRepository repository = FakeUserProfileRepository();
      final ProviderContainer container = await makeContainer(
        repository: repository,
      );
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );

      notifier.load(buildProfile());

      final EditProfileState state = container.read(editProfileProvider);
      expect(state.fullName, 'David Koné');
      expect(state.phone, '0700000000');
      expect(state.countryCode, '+225');
      expect(state.kioskName, 'Kiosque du Sud');
      expect(state.photoUrl, isNull);
    });
  });

  group('EditProfileNotifier.submit', () {
    test('skips the uniqueness check when phone is unchanged', () async {
      final FakeAuthGateway gateway = FakeAuthGateway();
      final FakeUserProfileRepository repository = FakeUserProfileRepository(
        initialProfile: buildProfile(),
      );
      final ProviderContainer container = await makeContainer(
        gateway: gateway,
        repository: repository,
      );
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );
      notifier.load(buildProfile());
      notifier.setFullName('David Kouassi');

      final bool succeeded = await notifier.submit();

      expect(succeeded, isTrue);
      expect(gateway.phoneInUseCalls, 0, reason: 'phone unchanged → no query');
      expect(container.read(editProfileProvider).saved, isTrue);
      expect(repository.updates, hasLength(1));
      final (String uid, UserProfileUpdate update) = repository.updates.single;
      expect(uid, 'uid');
      expect(update.fullName, 'David Kouassi');
      expect(update.kioskName, 'Kiosque du Sud');
    });

    test(
      'checks uniqueness with exceptUid when phone matches another account',
      () async {
        final FakeAuthGateway gateway = FakeAuthGateway();
        final FakeUserProfileRepository repository = FakeUserProfileRepository(
          initialProfile: buildProfile(),
        );
        gateway.registerPhone('+2250500000000', 'other@example.com');
        final ProviderContainer container = await makeContainer(
          gateway: gateway,
          repository: repository,
        );
        final EditProfileNotifier notifier = container.read(
          editProfileProvider.notifier,
        );
        notifier.load(buildProfile());
        notifier.setPhone('0500000000');

        final bool succeeded = await notifier.submit();

        expect(succeeded, isFalse);
        expect(gateway.phoneInUseCalls, 1);
        expect(gateway.lastCheckedCountryCode, '+225');
        expect(gateway.lastCheckedPhone, '0500000000');
        expect(gateway.lastExceptUid, 'uid');
        expect(
          container.read(editProfileProvider).errorMessage,
          phoneAlreadyInUseException.message,
        );
        expect(repository.updates, isEmpty);
      },
    );

    test('does not flag a phone the connected user already owns', () async {
      final FakeAuthGateway gateway = FakeAuthGateway();
      final FakeUserProfileRepository repository = FakeUserProfileRepository(
        initialProfile: buildProfile(),
      );
      gateway.registerOwnerPhone('+2250799999999');
      final ProviderContainer container = await makeContainer(
        gateway: gateway,
        repository: repository,
        authUid: 'self',
      );
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );
      notifier.load(buildProfile());
      notifier.setPhone('0799999999');

      final bool succeeded = await notifier.submit();

      expect(succeeded, isTrue);
      expect(gateway.phoneInUseCalls, 1);
      expect(gateway.lastExceptUid, 'self');
      expect(repository.updates, hasLength(1));
      expect(repository.updates.single.$2.phone, '0799999999');
    });

    test('propagates AuthException message on failure', () async {
      final FakeAuthGateway gateway = FakeAuthGateway();
      final FakeUserProfileRepository repository = _ThrowingProfileRepository();
      final ProviderContainer container = await makeContainer(
        gateway: gateway,
        repository: repository,
      );
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );
      notifier.load(buildProfile());

      final bool succeeded = await notifier.submit();

      expect(succeeded, isFalse);
      expect(container.read(editProfileProvider).errorMessage, 'Profil bloqué');
    });
  });

  group('EditProfileNotifier.uploadAvatar', () {
    test('stores the returned photo URL', () async {
      final FakeAvatarUploadService avatar = FakeAvatarUploadService(
        urlToReturn: 'https://example.com/me.jpg',
      );
      final ProviderContainer container = await makeContainer(avatar: avatar);
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );

      final bool succeeded = await notifier.uploadAvatar();

      expect(succeeded, isTrue);
      expect(avatar.calls, 1);
      expect(avatar.lastUid, 'uid');
      expect(
        container.read(editProfileProvider).photoUrl,
        'https://example.com/me.jpg',
      );
    });

    test('keeps the previous photo when the user cancels', () async {
      final FakeAvatarUploadService avatar = FakeAvatarUploadService(
        urlToReturn: 'https://example.com/me.jpg',
      );
      final FakeUserProfileRepository repository = FakeUserProfileRepository(
        initialProfile: buildProfile(),
      );
      final ProviderContainer container = await makeContainer(
        avatar: avatar,
        repository: repository,
      );
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );
      expect(await notifier.uploadAvatar(), isTrue);
      avatar.urlToReturn = null;

      final bool succeeded = await notifier.uploadAvatar();

      expect(succeeded, isFalse);
      expect(
        container.read(editProfileProvider).photoUrl,
        'https://example.com/me.jpg',
      );
    });

    test('reports upload failures as an error message', () async {
      final FakeAvatarUploadService avatar = FakeAvatarUploadService(
        shouldThrow: true,
      );
      final ProviderContainer container = await makeContainer(avatar: avatar);
      final EditProfileNotifier notifier = container.read(
        editProfileProvider.notifier,
      );

      final bool succeeded = await notifier.uploadAvatar();

      expect(succeeded, isFalse);
      expect(
        container.read(editProfileProvider).errorMessage,
        'Impossible de mettre à jour la photo, réessayez',
      );
    });
  });
}

class _ThrowingProfileRepository extends FakeUserProfileRepository {
  @override
  Future<void> updateProfile({
    required String uid,
    required UserProfileUpdate update,
  }) async {
    throw const AuthException('Profil bloqué');
  }
}
