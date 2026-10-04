import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/firebase_avatar_upload_service.dart';
import '../../domain/services/avatar_upload_service.dart';

final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  return FirebaseAvatarUploadService(
    picker: ImagePicker(),
    storage: FirebaseStorage.instance,
  );
});
