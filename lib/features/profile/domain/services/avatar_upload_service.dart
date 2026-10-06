/// Erreur de téléversement d'avatar, avec un message destiné à l'utilisateur.
class AvatarUploadException implements Exception {
  const AvatarUploadException(this.message);

  final String message;

  @override
  String toString() => 'AvatarUploadException: $message';
}

/// Sélectionne et téléverse la photo de profil de l'utilisateur.
abstract class AvatarUploadService {
  /// Ouvre la galerie, redimensionne et téléverse l'image vers le stockage
  /// d'images (Cloudinary).
  ///
  /// Retourne l'URL HTTPS publique de l'image, ou `null` si l'utilisateur
  /// annule la sélection. Lève [AvatarUploadException] en cas d'échec réseau ou
  /// de refus du service.
  Future<String?> pickAndUpload({required String uid});
}
