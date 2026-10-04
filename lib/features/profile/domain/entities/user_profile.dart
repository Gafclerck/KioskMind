/// Identité lue depuis le document `users/{uid}`.
///
/// Ce document est la source de vérité unique du profil : il est créé à
/// l'inscription (feature auth) et seulement lu/mis à jour ici.
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.phone,
    required this.countryCode,
    required this.email,
    this.createdAt,
    this.kioskName,
    this.marketLocation,
    this.businessType,
    this.photoUrl,
  });

  final String fullName;
  final String phone;
  final String countryCode;
  final String email;

  final DateTime? createdAt;
  final String? kioskName;
  final String? marketLocation;
  final String? businessType;
  final String? photoUrl;

  /// Initiales calculées depuis le nom complet, pour l'avatar de repli.
  String get initials => userInitials(fullName);
}

/// Utilitaire partagé : [userInitials] permet de calculer les initiales hors
/// d'un [UserProfile] (ex. édition du profil avant sauvegarde).
String userInitials(String fullName) {
  final String trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final List<String> parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Champs modifiables du profil. L'e-mail et la date de création ne sont pas
/// éditables : ils restent gérés par l'inscription.
class UserProfileUpdate {
  const UserProfileUpdate({
    required this.fullName,
    required this.phone,
    required this.countryCode,
    this.kioskName,
    this.marketLocation,
    this.businessType,
    this.photoUrl,
  });

  final String fullName;
  final String phone;
  final String countryCode;
  final String? kioskName;
  final String? marketLocation;
  final String? businessType;
  final String? photoUrl;
}
