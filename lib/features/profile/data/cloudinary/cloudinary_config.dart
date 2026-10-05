/// Configuration de l'API Unsigned Cloudinary utilisée pour téléverser les
/// photos de profil.
///
/// Les valeurs arrivent à la compilation et ne sont donc jamais écrites dans le
/// dépôt. On part du template du dépôt :
///
/// ```bash
/// cp .env.example .env   # puis renseigner les deux variables Cloudinary
/// flutter run --dart-define-from-file=.env
/// ```
///
/// En ligne de commande, pour une compilation ponctuelle :
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

  /// Vrai quand les deux valeurs sont exploitables à l'exécution.
  ///
  /// Une valeur laissée telle quelle dans `.env.example` (`votre_cloud_name`,
  /// `votre_preset_unsigned`) compte comme absente : sans cette garde, un
  /// fichier `.env` copié sans être édité produirait une erreur Cloudinary
  /// brute au lieu du message « service non configuré ».
  static bool get isConfigured => isUsable(cloudName) && isUsable(uploadPreset);

  /// Une valeur est exploitable si elle est renseignée et n'est pas un
  /// placeholder du template.
  static bool isUsable(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized.startsWith('votre_')) {
      return false;
    }
    // `env.json.example` porte la même convention de placeholder.
    return !normalized.contains('votre_');
  }

  /// Point d'entrée d'upload image, dérivé du nom du cloud.
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
