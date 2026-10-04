import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';

/// Maps the `users/{uid}` Firestore document to the [UserProfile] entity.
///
/// All mutable fields are optional on read so that documents created by older
/// flows (no kiosk fields yet) still hydrate correctly.
class UserProfileModel {
  const UserProfileModel._();

  static UserProfile? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    return UserProfile(
      fullName: _string(map['fullName']) ?? '',
      phone: _string(map['phone']) ?? '',
      countryCode: _string(map['countryCode']) ?? '',
      email: _string(map['email']) ?? '',
      createdAt: _date(map['createdAt']),
      kioskName: _string(map['kioskName']),
      marketLocation: _string(map['marketLocation']),
      businessType: _string(map['businessType']),
      photoUrl: _string(map['photoUrl']),
    );
  }

  /// Map written on update, merged with the existing document.
  static Map<String, dynamic> toUpdateMap(UserProfileUpdate update) {
    return <String, dynamic>{
      'fullName': update.fullName,
      'phone': update.phone,
      'countryCode': update.countryCode,
      'kioskName': update.kioskName,
      'marketLocation': update.marketLocation,
      'businessType': update.businessType,
      'photoUrl': update.photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String? _string(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
