/// Sélectionne et téléverse la photo de profil de l'utilisateur.
abstract class AvatarUploadService {
  /// Ouvre la galerie, redimensionne et uploade l'image vers Storage.
  ///
  /// Retourne l'URL publique de l'image, ou `null` si l'utilisateur annule.
  Future<String?> pickAndUpload({required String uid});
}
