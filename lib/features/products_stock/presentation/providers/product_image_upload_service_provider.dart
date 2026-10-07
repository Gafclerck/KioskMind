import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/cloudinary_config.dart';
import '../../data/services/cloudinary_product_image_upload_service.dart';
import '../../domain/services/product_image_upload_service.dart';

/// Service d'upload de photo de produit branché sur l'API Unsigned Cloudinary.
///
/// La configuration arrive par `--dart-define` (voir [CloudinaryConfig]). Sans
/// elle, on renvoie un service qui échoue explicitement plutôt que de laisser
/// croire à un upload réussi : le formulaire affiche l'erreur et la photo reste
/// celle d'avant.
final productImageUploadServiceProvider = Provider<ProductImageUploadService>((
  ref,
) {
  if (!CloudinaryConfig.isConfigured) {
    return const _UnconfiguredProductImageUploadService();
  }
  return CloudinaryProductImageUploadService(
    picker: ImagePicker(),
    cloudName: CloudinaryConfig.cloudName,
    uploadPreset: CloudinaryConfig.uploadPreset,
  );
});

class _UnconfiguredProductImageUploadService
    implements ProductImageUploadService {
  const _UnconfiguredProductImageUploadService();

  @override
  Future<String?> pickAndUpload() {
    throw const ProductImageUploadException(
      "Le service d'images n'est pas configuré pour cette build",
    );
  }
}
