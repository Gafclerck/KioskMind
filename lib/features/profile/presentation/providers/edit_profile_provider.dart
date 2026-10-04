import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/auth_gateway.dart';
import '../../../auth/presentation/providers/auth_gateway_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/user_profile.dart';
import 'avatar_upload_service_provider.dart';
import 'user_profile_provider.dart';

const Object _unset = Object();

class EditProfileState {
  const EditProfileState({
    this.fullName = '',
    this.phone = '',
    this.countryCode = '+225',
    this.kioskName,
    this.marketLocation,
    this.businessType,
    this.photoUrl,
    this.isSubmitting = false,
    this.isUploadingAvatar = false,
    this.errorMessage,
    this.saved = false,
  });

  final String fullName;
  final String phone;
  final String countryCode;
  final String? kioskName;
  final String? marketLocation;
  final String? businessType;
  final String? photoUrl;
  final bool isSubmitting;
  final bool isUploadingAvatar;
  final String? errorMessage;
  final bool saved;

  EditProfileState copyWith({
    String? fullName,
    String? phone,
    String? countryCode,
    Object? kioskName = _unset,
    Object? marketLocation = _unset,
    Object? businessType = _unset,
    Object? photoUrl = _unset,
    bool? isSubmitting,
    bool? isUploadingAvatar,
    Object? errorMessage = _unset,
    bool? saved,
  }) {
    return EditProfileState(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      kioskName: identical(kioskName, _unset)
          ? this.kioskName
          : kioskName as String?,
      marketLocation: identical(marketLocation, _unset)
          ? this.marketLocation
          : marketLocation as String?,
      businessType: identical(businessType, _unset)
          ? this.businessType
          : businessType as String?,
      photoUrl: identical(photoUrl, _unset)
          ? this.photoUrl
          : photoUrl as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      saved: saved ?? this.saved,
    );
  }
}

class EditProfileNotifier extends Notifier<EditProfileState> {
  UserProfile? _original;

  @override
  EditProfileState build() => const EditProfileState();

  void load(UserProfile? profile) {
    if (profile == null) {
      return;
    }
    _original = profile;
    state = const EditProfileState().copyWith(
      fullName: profile.fullName,
      phone: profile.phone,
      countryCode: profile.countryCode,
      kioskName: profile.kioskName,
      marketLocation: profile.marketLocation,
      businessType: profile.businessType,
      photoUrl: profile.photoUrl,
    );
  }

  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setPhone(String value) {
    state = state.copyWith(phone: value);
  }

  void setCountryCode(String value) {
    state = state.copyWith(countryCode: value);
  }

  void setKioskName(String value) {
    state = state.copyWith(kioskName: value);
  }

  void setMarketLocation(String value) {
    state = state.copyWith(marketLocation: value);
  }

  void setBusinessType(String value) {
    state = state.copyWith(businessType: value);
  }

  void clearSubmissionResult() {
    state = state.copyWith(errorMessage: null, saved: false);
  }

  String? get _uid => ref.read(authStateProvider).valueOrNull;

  /// Ouvre la galerie, téléverse la photo et renseigne [EditProfileState.photoUrl].
  ///
  /// Retourne `false` en cas d'échec (le message est dans [EditProfileState.errorMessage]).
  Future<bool> uploadAvatar() async {
    final String? uid = _uid;
    if (uid == null || state.isUploadingAvatar) {
      return false;
    }
    state = state.copyWith(isUploadingAvatar: true, errorMessage: null);
    try {
      final String? url = await ref
          .read(avatarUploadServiceProvider)
          .pickAndUpload(uid: uid);
      state = state.copyWith(
        isUploadingAvatar: false,
        photoUrl: url ?? state.photoUrl,
      );
      return url != null;
    } catch (_) {
      state = state.copyWith(
        isUploadingAvatar: false,
        errorMessage: 'Impossible de mettre à jour la photo, réessayez',
      );
      return false;
    }
  }

  Future<bool> submit() async {
    final String? uid = _uid;
    if (uid == null || state.isSubmitting || state.isUploadingAvatar) {
      return false;
    }

    final String countryCode = state.countryCode.trim();
    final String phone = state.phone.trim();

    final UserProfile? original = _original;
    final bool phoneChanged =
        original == null ||
        countryCode != original.countryCode ||
        _digits(phone) != _digits(original.phone);
    if (phoneChanged) {
      final bool inUse = await ref
          .read(authGatewayProvider)
          .isPhoneInUse(countryCode: countryCode, phone: phone, exceptUid: uid);
      if (inUse) {
        state = state.copyWith(
          errorMessage: phoneAlreadyInUseException.message,
        );
        return false;
      }
    }

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      saved: false,
    );
    try {
      await ref
          .read(updateUserProfileProvider)
          .call(
            uid: uid,
            update: UserProfileUpdate(
              fullName: state.fullName.trim(),
              phone: phone,
              countryCode: countryCode,
              kioskName: _nullIfEmpty(state.kioskName),
              marketLocation: _nullIfEmpty(state.marketLocation),
              businessType: _nullIfEmpty(state.businessType),
              photoUrl: _nullIfEmpty(state.photoUrl),
            ),
          );
      ref.invalidate(userProfileProvider);
      state = state.copyWith(isSubmitting: false, saved: true);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Une erreur est survenue, réessayez',
      );
      return false;
    }
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _nullIfEmpty(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

final editProfileProvider =
    NotifierProvider<EditProfileNotifier, EditProfileState>(
      EditProfileNotifier.new,
    );
