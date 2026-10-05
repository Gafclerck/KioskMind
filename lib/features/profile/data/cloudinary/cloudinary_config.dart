/// Configuration de l'API Unsigned Cloudinary utilisée pour téléverser les
/// photos de profil.
///
/// Les valeurs arrivent à la compilation via `--dart-define` et ne sont donc
/// jamais écrites dans le dépôt :
///
/// ```
/// flutter run \
///   --dart-define=CLOUDINARY_CLOUD_NAME=mon_cloud \
///   --dart-define=CLOUDINARY_UPLOAD_PRESET=mon_preset
/// ```
///
/// L'API Unsigned n'expose qu'un preset public (le secret de signature n'est
/// pas nécessaire), mais les valeurs restent hors du dépôt par discipline.
abstract final class CloudinaryConfig {
  const CloudinaryConfig._();

  /// Nom du cloud Cloudinary qui héberge les avatars.
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );

  /// Preset d'upload signé côté console Cloudinary, en mode unsigned.
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  /// Vrai quand les deux valeurs sont présentes à l'exécution.
  static bool get isConfigured =>
      cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  /// Point d'entrée d'upload image, dérivé du nom du cloud.
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
