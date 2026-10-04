import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/services/avatar_upload_service.dart';

class FirebaseAvatarUploadService implements AvatarUploadService {
  FirebaseAvatarUploadService({required this.picker, required this.storage});

  final ImagePicker picker;
  final FirebaseStorage storage;

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
    final Reference ref = storage.ref('profile_photos/$uid');
    final TaskSnapshot snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return snapshot.ref.getDownloadURL();
  }
}
