import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_mind/core/theme/app_theme.dart';
import 'package:kiosk_mind/core/widgets/app_toast.dart';
import 'package:kiosk_mind/features/auth/domain/auth_gateway.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_gateway_provider.dart';
import 'package:kiosk_mind/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:kiosk_mind/features/profile/domain/entities/user_profile.dart';
import 'package:kiosk_mind/features/profile/domain/usecases/update_user_profile.dart';
import 'package:kiosk_mind/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/avatar_upload_service_provider.dart';
import 'package:kiosk_mind/features/profile/presentation/providers/user_profile_provider.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

Future<void> pumpEditProfile(
  WidgetTester tester, {
  required FakeAuthGateway gateway,
  required FakeUserProfileRepository repository,
  FakeAvatarUploadService? avatar,
}) async {
  final UserProfile? profile = repository.profile;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value('uid')),
        userProfileProvider.overrideWith(
          (ref) => Stream<UserProfile?>.value(profile),
        ),
        authGatewayProvider.overrideWithValue(gateway),
        updateUserProfileProvider.overrideWith(
          (ref) => UpdateUserProfile(repository),
        ),
        avatarUploadServiceProvider.overrideWithValue(
          avatar ?? FakeAvatarUploadService(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (BuildContext context, Widget? child) {
          return AppToastHost(child: child ?? const SizedBox.shrink());
        },
        home: const EditProfilePage(),
      ),
    ),
  );

  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(EditProfilePage)),
  );
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Finder saveButton() => find.text('Enregistrer les modifications');

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(saveButton());
  await tester.pumpAndSettle();
  await tester.tap(saveButton());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills the form from the current profile', (tester) async {
    final FakeUserProfileRepository repository = FakeUserProfileRepository(
      initialProfile: UserProfile(
        fullName: 'David Koné',
        phone: '0700000000',
        countryCode: '+225',
        email: 'david@example.com',
        kioskName: 'Kiosque du Sud',
        marketLocation: 'Marché de Treichville',
        businessType: 'Alimentation générale',
      ),
    );
    await pumpEditProfile(
      tester,
      gateway: FakeAuthGateway(),
      repository: repository,
    );

    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.text('David Koné'), findsOneWidget);
    expect(find.text('0700000000'), findsOneWidget);
    expect(find.text('Kiosque du Sud'), findsOneWidget);
    expect(find.text('Marché de Treichville'), findsOneWidget);
    expect(find.text('Changer la photo'), findsOneWidget);
  });

  testWidgets('saves changed identity fields without re-checking the phone', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final FakeUserProfileRepository repository = FakeUserProfileRepository(
      initialProfile: UserProfile(
        fullName: 'David Koné',
        phone: '0700000000',
        countryCode: '+225',
        email: 'david@example.com',
      ),
    );
    await pumpEditProfile(tester, gateway: gateway, repository: repository);

    await tester.enterText(find.byType(TextFormField).at(0), 'David Kouassi');
    await tapSave(tester);

    expect(gateway.phoneInUseCalls, 0);
    expect(repository.updates, hasLength(1));
    expect(repository.updates.single.$2.fullName, 'David Kouassi');
    expect(find.text('Profil mis à jour'), findsOneWidget);
  });

  testWidgets('rejects a phone number already used by another account', (
    tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    gateway.registerPhone('+2250500000000', 'other@example.com');
    final FakeUserProfileRepository repository = FakeUserProfileRepository(
      initialProfile: UserProfile(
        fullName: 'David Koné',
        phone: '0700000000',
        countryCode: '+225',
        email: 'david@example.com',
      ),
    );
    await pumpEditProfile(tester, gateway: gateway, repository: repository);

    await tester.enterText(find.byType(TextFormField).at(1), '0500000000');
    await tapSave(tester);

    expect(gateway.phoneInUseCalls, 1);
    expect(gateway.lastCheckedCountryCode, '+225');
    expect(gateway.lastCheckedPhone, '0500000000');
    expect(gateway.lastExceptUid, 'uid');
    expect(repository.updates, isEmpty);
    expect(find.text(phoneAlreadyInUseException.message), findsOneWidget);
  });

  testWidgets('updates the avatar photo when the upload succeeds', (
    tester,
  ) async {
    final FakeAvatarUploadService avatar = FakeAvatarUploadService(
      urlToReturn: 'https://example.com/me.jpg',
    );
    final FakeUserProfileRepository repository = FakeUserProfileRepository(
      initialProfile: UserProfile(
        fullName: 'David Koné',
        phone: '0700000000',
        countryCode: '+225',
        email: 'david@example.com',
      ),
    );
    await pumpEditProfile(
      tester,
      gateway: FakeAuthGateway(),
      repository: repository,
      avatar: avatar,
    );

    await tester.tap(find.text('Changer la photo'));
    await tester.pumpAndSettle();

    expect(avatar.calls, 1);
    expect(avatar.lastUid, 'uid');
  });
}
