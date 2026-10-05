import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../domain/services/product_image_upload_service.dart';

/// Téléverse la photo choisie dans la galerie vers Cloudinary (API Unsigned) et
/// renvoie l'URL HTTPS publique de l'image.
///
/// Chaque envoi part sans `public_id` : Cloudinary attribue un nom unique, donc
/// le produit n'a pas besoin d'être déjà enregistré et une nouvelle photo n'écrase
/// pas la précédente. Le revers est qu'un remplacement laisse l'ancien fichier
/// derrière soi, à purger côté console Cloudinary. Renvoyer l'identifiant public
/// jusqu'au document Firestore (`imagePublicId`) lèverait cette limite ; c'est le
/// premier endroit à regarder si l'accumulation devient un problème.
class CloudinaryProductImageUploadService implements ProductImageUploadService {
  CloudinaryProductImageUploadService({
    required this.picker,
    required this.cloudName,
    required this.uploadPreset,
    this.maxDimension = 1024,
    this.quality = 85,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final ImagePicker picker;
  final String cloudName;
  final String uploadPreset;

  /// Côté le plus long de l'image avant téléversement. Un produit est vu en plus
  /// grand qu'un avatar, d'où 1024 px par défaut contre 512 px pour l'avatar.
  final double maxDimension;

  final int quality;
  final http.Client _client;

  @override
  Future<String?> pickAndUpload() async {
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
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
      }),
    );

    if (response.statusCode != 200) {
      throw ProductImageUploadException(
        "Cloudinary a refusé l'image du produit (code ${response.statusCode})",
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ProductImageUploadException('Réponse Cloudinary illisible');
    }
    final Object? secureUrl = decoded['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const ProductImageUploadException(
        "URL de l'image absente de la réponse",
      );
    }
    return secureUrl;
  }
}
