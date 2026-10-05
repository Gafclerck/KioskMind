/// Erreur de téléversement d'image de produit, avec un message destiné à
/// l'utilisateur.
class ProductImageUploadException implements Exception {
  const ProductImageUploadException(this.message);

  final String message;

  @override
  String toString() => 'ProductImageUploadException: $message';
}

/// Ouvre la galerie, téléverse la photo choisie vers le stockage d'images
/// (Cloudinary).
///
/// Retourne l'URL HTTPS publique de l'image, ou `null` si l'utilisateur annule
/// la sélection. Lève [ProductImageUploadException] en cas d'échec réseau ou
/// de refus du service.
///
/// Le port ne renvoie que l'URL : le type `XFile` du plugin de sélection reste
/// dans la couche data, pour que le domaine demeure du Dart pur.
abstract interface class ProductImageUploadService {
  Future<String?> pickAndUpload();
}
