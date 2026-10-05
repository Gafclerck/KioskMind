import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../domain/services/avatar_upload_service.dart';

/// Téléverse la photo choisie dans la galerie vers Cloudinary (API Unsigned)
/// et renvoie l'URL HTTPS publique de l'image.
///
/// Les quotas et les règles d'accès de Firebase Storage ne s'appliquent plus :
/// seule la configuration du preset Cloudinary conditionne le succès.
class CloudinaryAvatarUploadService implements AvatarUploadService {
  CloudinaryAvatarUploadService({
    required this.picker,
    required this.cloudName,
    required this.uploadPreset,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final ImagePicker picker;
  final String cloudName;
  final String uploadPreset;
  final http.Client _client;

  @override
  Future<String?> pickAndUpload({required String uid}) async {
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    final http.Response response = await _client.post(
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: jsonEncode(<String, dynamic>{
        'upload_preset': uploadPreset,
        'file': 'data:image/jpeg;base64,${base64Encode(bytes)}',
        // Un seul emplacement par utilisateur : la nouvelle photo remplace la
        // précédente côté Cloudinary au lieu de s'accumuler.
        'public_id': 'profile_$uid',
        'overwrite': true,
        'invalidate': true,
      }),
    );

    if (response.statusCode != 200) {
      throw AvatarUploadException(
        'Cloudinary a refusé le téléversement (code ${response.statusCode})',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AvatarUploadException('Réponse Cloudinary illisible');
    }
    final Object? secureUrl = decoded['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const AvatarUploadException("URL de l'image absente de la réponse");
    }
    return secureUrl;
  }
}
