import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/cloudinary/cloudinary_config.dart';
import '../../data/services/cloudinary_avatar_upload_service.dart';
import '../../domain/services/avatar_upload_service.dart';

/// Service d'upload d'avatar branché sur l'API Unsigned Cloudinary.
///
/// La configuration arrive par `--dart-define` (voir [CloudinaryConfig]). Sans
/// elle, on renvoie un service qui échoue explicitement plutôt que de laisser
/// croire à un upload réussi : l'erreur est remontée à l'utilisateur en toast.
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  if (!CloudinaryConfig.isConfigured) {
    return const _UnconfiguredAvatarUploadService();
  }
  return CloudinaryAvatarUploadService(
    picker: ImagePicker(),
    cloudName: CloudinaryConfig.cloudName,
    uploadPreset: CloudinaryConfig.uploadPreset,
  );
});

class _UnconfiguredAvatarUploadService implements AvatarUploadService {
  const _UnconfiguredAvatarUploadService();

  @override
  Future<String?> pickAndUpload({required String uid}) {
    throw const AvatarUploadException(
      "Le service d'images n'est pas configuré pour cette build",
    );
  }
}
